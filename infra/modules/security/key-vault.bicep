param location string
@minLength(3)
@maxLength(24)
param vaultName string
@secure()
param postgresAdminSecret string
param postgresAdminLogin string
param postgresFqdn string
param databaseName string
param todoApiDatabaseUsername string
@secure()
param todoApiDatabasePassword string
param appIdentityPrincipalId string
param privateEndpointSubnetId string
param privateDnsZoneId string

var keyVaultSecretsUserRoleGuid = '4633458b-17de-408a-b874-0445c86b69e6'

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${vault.name}-private-endpoint'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${vault.name}-connection'
        properties: {
          privateLinkServiceId: vault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'key-vault-zone'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

resource adminPassword 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'postgres-admin-password'
  properties: {
    value: postgresAdminSecret
    contentType: 'PostgreSQL administrator password'
  }
}
resource adminLogin 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'postgres-admin-username'
  properties: {
    value: postgresAdminLogin
  }
}
resource serverFqdn 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'postgres-fqdn'
  properties: {
    value: postgresFqdn
  }
}
resource dbName 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'postgres-database-name'
  properties: {
    value: databaseName
  }
}
resource todoApiDbUrl 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'todo-api-db-url'
  properties: {
    value: 'jdbc:postgresql://${postgresFqdn}:5432/${databaseName}?sslmode=require'
  }
}
resource todoApiDbUsername 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'todo-api-db-username'
  properties: {
    value: todoApiDatabaseUsername
  }
}
resource todoApiDbPassword 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: vault
  name: 'todo-api-db-password'
  properties: {
    value: todoApiDatabasePassword
  }
}

resource todoApiDbUrlReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(todoApiDbUrl.id, appIdentityPrincipalId, keyVaultSecretsUserRoleGuid)
  scope: todoApiDbUrl
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      keyVaultSecretsUserRoleGuid
    )
    principalId: appIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
resource todoApiDbUsernameReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(todoApiDbUsername.id, appIdentityPrincipalId, keyVaultSecretsUserRoleGuid)
  scope: todoApiDbUsername
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      keyVaultSecretsUserRoleGuid
    )
    principalId: appIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
resource todoApiDbPasswordReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(todoApiDbPassword.id, appIdentityPrincipalId, keyVaultSecretsUserRoleGuid)
  scope: todoApiDbPassword
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      keyVaultSecretsUserRoleGuid
    )
    principalId: appIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output vaultUri string = vault.properties.vaultUri
output vaultId string = vault.id
output vaultName string = vault.name
output privateEndpointId string = privateEndpoint.id
