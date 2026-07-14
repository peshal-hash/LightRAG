#!/bin/bash

# Development Environment Configuration
ENVIRONMENT_NAME="Development"
RESOURCE_GROUP="testing-containers"
ACR_NAME="salesopttest"
LOCATION="canadacentral"
BICEP_FILE="${SCRIPT_DIR}/main.bicep"
KEY_VAULT_NAME="salesopt-kv-test"

POSTGRES_SERVER_NAME="salesopt-pg-server-dev"
POSTGRES_ADMIN_USER="salesoptadmin"

APP_NAME_LIGHTRAG="salesopt-lightrag"

DEPLOY_NEW_INFRA='false'
