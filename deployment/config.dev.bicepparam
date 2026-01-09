using './main.bicep'

param location = 'canadacentral'
param environmentName = 'testAPContainerEnvironment'
param acrName = 'salesopttest'
param appImageTag = 'latest'
param revisionSuffix = ''
param keyVaultName = 'salesopt-kv-test'

// reuse Activepieces postgres flexible server
param postgresServerName = 'salesopt-pg-server-dev-b7e59be4'
param postgresAdminUser = 'salesoptadmin'
