using './main-dev.bicep'

param location = 'canadacentral'
param environmentName = 'testAPContainerEnvironment'
param appName = 'salesopt-lightrag-dev'
param acrName = 'salesopttest'
param appImageTag = 'latest'
param revisionSuffix = ''
param keyVaultName = 'salesopt-kv-test'

// reuse Activepieces postgres flexible server
param postgresServerName = 'salesopt-pg-server-dev'
param postgresAdminUser = 'salesoptadmin'
