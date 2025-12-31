param location string
param environmentName string = 'testAPContainerEnvironment'
param acrName string = 'salesopttest'
param appImageTag string = 'latest'
param revisionSuffix string = ''
param keyVaultName string 

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
              name: 'LLM_BINDING'
              value: 'openai'
            }
            {
              name: 'LLM_MODEL'
              value: 'gpt-4o'
            }
            {
              name: 'LLM_BINDING_API_KEY'
              secretRef: 'openai-api-key'
            }

            {
              name: 'EMBEDDING_BINDING'
              value: 'openai'
            }
            {
              name: 'EMBEDDING_MODEL'
              value: 'text-embedding-3-large'
            }
            {
              name: 'EMBEDDING_DIM'
              value: '3072'
            }
            {
              name: 'EMBEDDING_SEND_DIM'
              value: 'false'
            }
            {
              name: 'EMBEDDING_BINDING_API_KEY'
              secretRef: 'openai-api-key'
            }

            // --- Directories (Internal Storage) ---
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

// --- OUTPUTS ---
output appUrl string = lightRAG.properties.configuration.ingress.fqdn
