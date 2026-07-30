#!/bin/bash

# Development Environment Configuration
ENVIRONMENT_NAME="Production"
RESOURCE_GROUP="salesoptai-container-prod"
ACR_NAME="salesoptaiprod"
LOCATION="canadacentral"

# User-assigned identity used for ACR pull + Key Vault secret access.
# Must be 'salesoptai-prod-identity' -- it is the only identity holding both
# AcrPull on salesoptaiprod and Key Vault Secrets User on salesoptai-prod-keyvault.
MANAGED_IDENTITY_NAME="salesoptai-prod-identity"
BICEP_FILE="${SCRIPT_DIR}/main.bicep"
KEY_VAULT_NAME="salesoptai-prod-keyvault"

# Azure Container App managed environment (passed to bicep)
# Prod runs in testAPContainerEnvironment (Canada Central), alongside the
# lightragfilesprod01 storage account and salesopt-pg-server-prod, which are
# also Canada Central. Moving to 'salesoptai-prod-environment' (Canada East)
# would require deleting/recreating the app (environment is immutable), a new
# FQDN, and cross-region storage + Postgres mounts. Keep both in sync with
# LOCATION above -- a container app must be in the same region as its environment.
AZURE_ENVIRONMENT_NAME="testAPContainerEnvironment"
AZURE_ENVIRONMENT_RESOURCE_GROUP="testing-containers"

POSTGRES_SERVER_NAME="salesopt-pg-server-prod"
POSTGRES_ADMIN_USER="salesoptadmin"

APP_NAME_LIGHTRAG="salesopt-lightrag"

DEPLOY_NEW_INFRA='false'
