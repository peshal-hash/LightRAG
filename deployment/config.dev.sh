#!/bin/bash

# Development Environment Configuration
ENVIRONMENT_NAME="Development"
RESOURCE_GROUP="testing-containers"
ACR_NAME="salesopttest"
LOCATION="canadacentral"
BICEP_FILE="./main.bicep"
KEY_VAULT_NAME="salesopt-kv-test"

POSTGRES_SERVER_NAME="salesopt-pg-server-dev-b7e59be4"
POSTGRES_ADMIN_USER="salesoptadmin"

APP_NAME_LIGHTRAG="salesopt-lightrag"

DEPLOY_NEW_INFRA='false'
