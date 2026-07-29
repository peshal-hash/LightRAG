param location string
param environmentName string = 'testAPContainerEnvironment'
param appName string = 'salesopt-lightrag'
param acrName string = 'salesoptaiprod'
param managedIdentityName string = 'salesoptai-prod-identity'
param appImageTag string = 'latest'
param revisionSuffix string = ''
param keyVaultName string

param postgresServerName string
param postgresAdminUser string

param lightragStorageAccountName string = 'lightragfilesprod01'
param lightragRagShareName string = 'rag-storage'
param lightragInputsShareName string = 'inputs'
param lightragTiktokenShareName string = 'tiktoken-cache'
param useExistingStorage bool = true
param runPgVectorInit bool = false

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource existingEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: environmentName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource existingPostgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' existing = {
  name: postgresServerName
}

var postgresHost = existingPostgresServer.properties.fullyQualifiedDomainName

resource lightragDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: existingPostgresServer
  name: 'lightrag'
}

resource postgresFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  parent: existingPostgresServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource pgExtensions 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2022-12-01' = if (runPgVectorInit) {
  parent: existingPostgresServer
  name: 'azure.extensions'
  properties: {
    value: 'vector'
    source: 'user-override'
  }
}

resource initPgVector 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (runPgVectorInit) {
  name: 'init-lightrag-pgvector'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.55.0'
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    // Any change here forces script re-run on redeploys
    forceUpdateTag: '${uniqueString(resourceGroup().id, revisionSuffix, appImageTag)}'

    environmentVariables: [
      {
        name: 'KV_NAME'
        value: keyVaultName
      }
      {
        name: 'PG_HOST'
        value: postgresHost
      }
      {
        name: 'PG_USER'
        value: postgresAdminUser
      }
      {
        name: 'PG_DB'
        value: 'lightrag'
      }
    ]

    scriptContent: '''
    #!/bin/bash
    set -euo pipefail

    echo "Installing psql client..."
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update -y
      apt-get install -y postgresql-client ca-certificates
    elif command -v tdnf >/dev/null 2>&1; then
      tdnf -y install postgresql ca-certificates
    elif command -v apk >/dev/null 2>&1; then
      apk add --no-cache postgresql-client ca-certificates
    else
      echo "No supported package manager found (apt-get/tdnf/apk)."
      exit 1
    fi

    echo "Reading Postgres password from Key Vault: ${KV_NAME}"
    export PGPASSWORD="$(az keyvault secret show --vault-name "${KV_NAME}" --name "POSTGRES-PASSWORD" --query value -o tsv)"
    echo "Enabling pgvector (vector extension) on database ${PG_DB}..."
    psql "host=${PG_HOST} port=5432 dbname=${PG_DB} user=${PG_USER} sslmode=require" \
      -v ON_ERROR_STOP=1 \
      -c "CREATE EXTENSION IF NOT EXISTS vector;"

    echo "pgvector enabled."
    '''
  }
  dependsOn: [
    postgresFirewallRule
    lightragDatabase
    pgExtensions
  ]
}

resource lightragStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = if (!useExistingStorage) {
  name: lightragStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

param lightragStorageResourceGroup string = resourceGroup().name
resource lightragStorageExisting 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (useExistingStorage) {
  name: lightragStorageAccountName
  scope: resourceGroup(lightragStorageResourceGroup)
}

var lightragStorageName = lightragStorageAccountName
var lightragStorageKey = useExistingStorage
  ? lightragStorageExisting.listKeys().keys[0].value
  : lightragStorage.listKeys().keys[0].value

var storageDependsOn = useExistingStorage ? [] : [lightragStorage]

resource ragShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${lightragStorageName}/default/${lightragRagShareName}'
  properties: { shareQuota: 100 }
  dependsOn: storageDependsOn
}

resource inputsShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${lightragStorageName}/default/${lightragInputsShareName}'
  properties: { shareQuota: 100 }
  dependsOn: storageDependsOn
}

resource tiktokenShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${lightragStorageName}/default/${lightragTiktokenShareName}'
  properties: { shareQuota: 10 }
  dependsOn: storageDependsOn
}

resource ragEnvStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: existingEnvironment
  name: 'rag-storage'
  properties: {
    azureFile: {
      accountName: lightragStorageName
      shareName: lightragRagShareName
      accountKey: lightragStorageKey
      accessMode: 'ReadWrite'
    }
  }
  dependsOn: [
    ragShare
  ]
}

resource inputsEnvStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: existingEnvironment
  name: 'inputs-storage'
  properties: {
    azureFile: {
      accountName: lightragStorageName
      shareName: lightragInputsShareName
      accountKey: lightragStorageKey
      accessMode: 'ReadWrite'
    }
  }
  dependsOn: [
    inputsShare
  ]
}

resource tiktokenEnvStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = {
  parent: existingEnvironment
  name: 'tiktoken-storage'
  properties: {
    azureFile: {
      accountName: lightragStorageName
      shareName: lightragTiktokenShareName
      accountKey: lightragStorageKey
      accessMode: 'ReadWrite'
    }
  }
  dependsOn: [
    tiktokenShare
  ]
}

resource lightRAG 'Microsoft.App/containerApps@2023-05-01' = {
  name: appName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: existingEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 9621
        transport: 'auto'
        corsPolicy: {
          allowedOrigins: [
            'https://portal.salesoptai.com'
            'https://portal.salesoptai.ai'
            'https://portal.nexopta.com'
            'http://localhost:3000'
          ]
          allowedMethods: ['*']
          allowedHeaders: ['*']
        }
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: managedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'lightrag-api-key'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/LIGHTRAG-API-KEY'
          identity: managedIdentity.id
        }
        {
          name: 'lightrag-files-key'
          value: lightragStorageKey
        }
        {
          name: 'azure-openai-api-key'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/AZURE-OPENAI-API-KEY'
          identity: managedIdentity.id
        }
        {
          name: 'postgres-admin-password'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/POSTGRES-PASSWORD'
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      revisionSuffix: revisionSuffix
      containers: [
        {
          image: '${acr.properties.loginServer}/salesopt-lightrag:${appImageTag}'
          name: 'lightrag-service'
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          env: [
            {
              name: 'HOST'
              value: '0.0.0.0'
            }
            {
              name: 'PORT'
              value: '9621'
            }
            {
              name: 'LIGHTRAG_API_KEY'
              secretRef: 'lightrag-api-key'
            }

            {
              name: 'LIGHTRAG_KV_STORAGE'
              value: 'PGKVStorage'
            }
            {
              name: 'LIGHTRAG_DOC_STATUS_STORAGE'
              value: 'PGDocStatusStorage'
            }
            {
              name: 'LIGHTRAG_GRAPH_STORAGE'
              value: 'NetworkXStorage'
            }
            {
              name: 'LIGHTRAG_VECTOR_STORAGE'
              value: 'PGVectorStorage'
            }

            {
              name: 'POSTGRES_HOST'
              value: postgresHost
            }
            {
              name: 'POSTGRES_PORT'
              value: '5432'
            }
            {
              name: 'POSTGRES_USER'
              value: postgresAdminUser
            }
            {
              name: 'POSTGRES_PASSWORD'
              secretRef: 'postgres-admin-password'
            }
            {
              name: 'POSTGRES_DATABASE'
              value: 'lightrag'
            }
            {
              name: 'POSTGRES_MAX_CONNECTIONS'
              value: '12'
            }
            {
              name: 'POSTGRES_SSL_MODE'
              value: 'require'
            }
            {
              name: 'AZURE_OPENAI_API_VERSION'
              value: '2024-12-01-preview'
            }
            {
              name: 'LLM_BINDING'
              value: 'azure_openai'
            }
            {
              name: 'LLM_BINDING_HOST'
              value: 'https://nexopta-ai-prod.services.ai.azure.com/'
            }
            {
              name: 'LLM_MODEL'
              value: 'gpt-5.6-luna'
            }
            {
              name: 'LLM_BINDING_API_KEY'
              secretRef: 'azure-openai-api-key'
            }
            {
              name: 'AZURE_EMBEDDING_API_VERSION'
              value: '2024-12-01-preview'
            }
            {
              name: 'EMBEDDING_BINDING'
              value: 'azure_openai'
            }
            {
              name: 'EMBEDDING_MODEL'
              value: 'text-embedding-3-small'
            }
            {
              name: 'EMBEDDING_DIM'
              value: '1536'
            }
            {
              name: 'EMBEDDING_BINDING_HOST'
              value: 'https://nexopta-ai-prod.services.ai.azure.com/'
            }
            {
              name: 'EMBEDDING_API_KEY'
              secretRef: 'azure-openai-api-key'
            }
            {
              name: 'TIKTOKEN_CACHE_DIR'
              value: '/app/data/tiktoken'
            }
            {
              name: 'INPUT_DIR'
              value: '/app/inputs'
            }
            {
              name: 'WORKING_DIR'
              value: '/app/rag_storage'
            }
            {
              name: 'CHUNK_SIZE'
              value: '2500'
            }
          ]
          volumeMounts: [
            {
              volumeName: 'rag-storage-vol'
              mountPath: '/app/rag_storage'
            }
            {
              volumeName: 'inputs-vol'
              mountPath: '/app/inputs'
            }
            {
              volumeName: 'tiktoken-vol'
              mountPath: '/app/data/tiktoken'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: 'rag-storage-vol'
          storageType: 'AzureFile'
          storageName: ragEnvStorage.name
        }
        {
          name: 'inputs-vol'
          storageType: 'AzureFile'
          storageName: inputsEnvStorage.name
        }
        {
          name: 'tiktoken-vol'
          storageType: 'AzureFile'
          storageName: tiktokenEnvStorage.name
        }
      ]
    }
  }
  dependsOn: useExistingStorage
    ? [
        ragShare
        inputsShare
        tiktokenShare
        ragEnvStorage
        inputsEnvStorage
        tiktokenEnvStorage
      ]
    : [
        ragShare
        inputsShare
        tiktokenShare
        lightragStorage
        ragEnvStorage
        inputsEnvStorage
        tiktokenEnvStorage
      ]
}

output appUrl string = lightRAG.properties.configuration.ingress.fqdn
