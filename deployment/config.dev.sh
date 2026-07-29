#!/bin/bash

# Development Environment Configuration
ENVIRONMENT_NAME="Development"
RESOURCE_GROUP="testing-containers"
ACR_NAME="salesopttest"
LOCATION="canadacentral"
BICEP_FILE="${SCRIPT_DIR}/main-dev.bicep"
KEY_VAULT_NAME="salesopt-kv-test"
AZURE_ENVIRONMENT_NAME="testAPContainerEnvironment"

# Dev keeps salesopt-container-identity: in the testing-containers RG this
# resolves to the identity that already holds AcrPull on salesopttest and
# Key Vault Secrets User on salesopt-kv-test.
MANAGED_IDENTITY_NAME="salesopt-container-identity"

POSTGRES_SERVER_NAME="salesopt-pg-server-dev"
POSTGRES_ADMIN_USER="salesoptadmin"

APP_NAME_LIGHTRAG="salesopt-lightrag-dev"

DEPLOY_NEW_INFRA='false'
