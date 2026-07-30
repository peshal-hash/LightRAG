using './main.bicep'

param location = 'canadacentral'
param environmentName = 'testAPContainerEnvironment'
// The environment lives in testing-containers, not salesoptai-container-prod.
param environmentResourceGroup = 'testing-containers'
param appName = 'salesopt-lightrag'
param acrName = 'salesoptaiprod'
param managedIdentityName = 'salesoptai-prod-identity'
param appImageTag = 'latest'
param revisionSuffix = ''
param keyVaultName = 'salesoptai-prod-keyvault'
param postgresServerName = 'salesopt-pg-server-prod'
param postgresAdminUser = 'salesoptadmin'
