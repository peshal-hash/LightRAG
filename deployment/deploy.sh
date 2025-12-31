#!/bin/bash
set -euo pipefail

# --- Argument Parsing ---
if [[ $# -eq 0 ]] ; then
    echo "Usage: ./deploy.sh --environment <dev|prod>" >&2
    exit 1
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter passed: $1" >&2
      exit 1
      ;;
  esac
done

# --- Load Configuration ---
CONFIG_FILE="./config.${ENVIRONMENT}.sh"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi
source "$CONFIG_FILE"

# --- Global Variables ---
ACR_SERVER="${ACR_NAME}.azurecr.io"
BUILD_TIMESTAMP=$(date +%Y%m%d%H%M%S)
GIT_SHA=${GITHUB_SHA:-$(git rev-parse --short HEAD)}
GIT_SHA_SHORT=$(echo "${GIT_SHA}" | cut -c1-7)
IMAGE_TAG="${GIT_SHA_SHORT}-${BUILD_TIMESTAMP}"
REVISION_SUFFIX="${GIT_SHA_SHORT}-${BUILD_TIMESTAMP}"

# --- Logging ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
write_info() { echo -e "${YELLOW}[INFO] $1${NC}" >&2; }
write_success() { echo -e "${GREEN}[SUCCESS] $1${NC}" >&2; }
write_error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }

# --- Error Handling & Rollback ---
function cleanup_on_error() {
  write_error "${ENVIRONMENT_NAME} deployment failed. Initiating rollback..."
  rollback_deployment
  exit 1
}
trap cleanup_on_error ERR

function rollback_deployment() {
  write_info "Attempting to roll back the failed deployment..."
  # Check if revision mode is multiple (unlikely for this simple setup but good practice)
  # For Single mode, we usually just want to check traffic
  local previous_revision=$(az containerapp revision list -n "$APP_NAME_LIGHTRAG" -g "$RESOURCE_GROUP" --query "[?properties.trafficWeight > 0 && !contains(name, '${REVISION_SUFFIX}')].name | [0]" -o tsv)
  
  if [[ -n "$previous_revision" ]]; then
    write_info "Shifting traffic back to stable revision: $previous_revision"
    az containerapp ingress traffic set -n "$APP_NAME_LIGHTRAG" -g "$RESOURCE_GROUP" --revision-weight "$previous_revision=100"
    write_success "Rollback successful. Traffic routed to $previous_revision."
  else
    write_error "No previous stable revision found to roll back to or check failed."
  fi
}

# --- Core Functions ---
function validate_prerequisites() {
  for tool in az docker jq curl; do
    if ! command -v $tool &> /dev/null; then write_error "$tool is required." && exit 1; fi
  done
  if ! az account show &>/dev/null; then write_error "Azure login required." && exit 1; fi
  write_success "Prerequisites validated."
}

function build_and_push_image() {
  local service_name=$1
  local dockerfile_path=$2
  local context_path=$3
  local acr_image_name=$(basename "$service_name")

  write_info "Building ${acr_image_name} from ${dockerfile_path}..."
  # Explicitly pointing to context (..) and dockerfile (../Dockerfile)
  docker build -t "${ACR_SERVER}/${acr_image_name}:${IMAGE_TAG}" -f "$dockerfile_path" "$context_path" >&2

  write_info "Pushing ${ACR_SERVER}/${acr_image_name}:${IMAGE_TAG}..."
  docker push "${ACR_SERVER}/${acr_image_name}:${IMAGE_TAG}" >&2
  write_success "${acr_image_name} image pushed."
}

function deploy_infrastructure() {
    write_info "Starting Bicep deployment for ${ENVIRONMENT_NAME} environment..."
    
    # FIX: Updated parameters to match lightrag.bicep
    # 1. changed appImageTag -> appImageTag
    # 2. added keyVaultName (required by bicep)
    # 3. changed output query to appUrl
    az deployment group create \
      --resource-group "$RESOURCE_GROUP" \
      --template-file "$BICEP_FILE" \
      --parameters appImageTag="$IMAGE_TAG" location="$LOCATION" revisionSuffix="$REVISION_SUFFIX" keyVaultName="$KEY_VAULT_NAME" \
      --debug \
      --query "properties.outputs.appUrl.value" \
      -o tsv
}

function health_check() {
  local app_url=$1
  # FIX: LightRAG usually has a /health endpoint. checking root / might 404.
  local health_endpoint="https://$app_url/health"
  
  write_info "Performing health check on $health_endpoint..."
  for i in {1..20}; do
    # Allow 404 temporarily if /health isn't implemented, but prefer 200
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$health_endpoint" || true)
    
    # LightRAG /health returns 200 OK
    if [[ "$http_code" -eq 200 ]]; then
      write_success "Health check passed with status $http_code!"
      return 0
    fi
    write_info "Attempt $i/20 failed with status $http_code, retrying in 5s..."
    sleep 5
  done
  write_error "Health check failed for $app_url."
  return 1
}

# --- Main Execution ---
function main() {
  write_success "Starting ${ENVIRONMENT_NAME} deployment..."
  write_info "Deployment ID: ${REVISION_SUFFIX}"

  validate_prerequisites

  write_info "Logging in to Azure Container Registry: $ACR_NAME"
  az acr login --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP"

  # Build LightRAG
  # Context is ".." (root), Dockerfile is "../Dockerfile"
  build_and_push_image "$APP_NAME_LIGHTRAG" "../Dockerfile" ".." &
  local pid_lightrag_build=$!

  # Wait for build
  local final_status=0
  wait $pid_lightrag_build || final_status=$?

  if [ $final_status -ne 0 ]; then
      write_error "Image build failed. Please review the logs above for the Docker error."
      exit 1
  fi
  write_success "LightRAG image built and pushed."
    
  # Deploy using Bicep
  local app_fqdn=$(deploy_infrastructure)
  if [[ -z "$app_fqdn" ]]; then
    write_error "Failed to get App FQDN from Bicep deployment output."
    exit 1
  fi
  
  # Final health check
  health_check "$app_fqdn"

  echo "" >&2
  write_success "=== ${ENVIRONMENT_NAME} DEPLOYMENT COMPLETED ==="
  write_success "Application URL: https://$app_fqdn"
  write_success "Image Tag: $IMAGE_TAG"
}

main