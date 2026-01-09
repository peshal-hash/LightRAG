param location string
param environmentName string = 'testAPContainerEnvironment'
param acrName string = 'salesopttest'
param appImageTag string = 'latest'
param revisionSuffix string = ''
param keyVaultName string

// Reuse the same Postgres Flexible Server that Activepieces uses
param postgresServerName string
param postgresAdminUser string


// --- EXISTING RESOURCES ---
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'salesopt-container-identity'
}

resource existingEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: environmentName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

// Existing Postgres server (same one Activepieces uses)
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

// --- LIGHTRAG CONTAINER APP ---
resource lightRAG 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'salesopt-lightrag'
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
          name: 'openai-api-key'
          keyVaultUrl: '${keyVault.properties.vaultUri}secrets/OPENAI-API-KEY'
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
            // --- Server Configuration ---
            { name: 'HOST' value: '0.0.0.0' }
            { name: 'PORT' value: '9621' }
            { name: 'LIGHTRAG_API_KEY' secretRef: 'lightrag-api-key' }
            { name: 'LIGHTRAG_KV_STORAGE' value: 'PGKVStorage' }
            { name: 'LIGHTRAG_DOC_STATUS_STORAGE' value: 'PGDocStatusStorage' }
            { name: 'LIGHTRAG_GRAPH_STORAGE' value: 'NetworkXStorage' }
            { name: 'LIGHTRAG_VECTOR_STORAGE' value: 'PGVectorStorage' }

            { name: 'POSTGRES_HOST' value: postgresHost }
            { name: 'POSTGRES_PORT' value: '5432' }
            { name: 'POSTGRES_USER' value: postgresAdminUser }
            { name: 'POSTGRES_PASSWORD' secretRef: 'postgres-admin-password' }
            { name: 'POSTGRES_DATABASE' value: 'lightrag' }
            { name: 'POSTGRES_MAX_CONNECTIONS' value: '12' }
            { name: 'POSTGRES_SSL_MODE' value: 'require' }

            { name: 'LLM_BINDING' value: 'openai' }
            { name: 'LLM_MODEL' value: 'gpt-4o' }
            { name: 'LLM_BINDING_API_KEY' secretRef: 'openai-api-key' }

            // --- Embeddings ---
            { name: 'EMBEDDING_BINDING' value: 'openai' }
            { name: 'EMBEDDING_MODEL' value: 'text-embedding-3-large' }
            { name: 'EMBEDDING_DIM' value: '3072' }
            { name: 'EMBEDDING_SEND_DIM' value: 'false' }
            { name: 'EMBEDDING_BINDING_API_KEY' secretRef: 'openai-api-key' }

            // --- Directories ---
            { name: 'TIKTOKEN_CACHE_DIR' value: '/app/data/tiktoken' }
            { name: 'INPUT_DIR' value: '/app/inputs' }
            { name: 'WORKING_DIR' value: '/app/rag_storage' }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}

output appUrl string = lightRAG.properties.configuration.ingress.fqdn
