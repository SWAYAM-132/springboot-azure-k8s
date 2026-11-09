param location string
@minLength(3)
@maxLength(24)
param vaultName string
@secure()
param postgresAdminSecret string
param postgresAdminLogin string
param postgresFqdn string
param databaseName string

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
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
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

output vaultUri string = vault.properties.vaultUri
output vaultId string = vault.id
