targetScope = 'subscription'
param dataResourceGroupName string = 'rg-todo-data-ci'
param networkResourceGroupName string = 'rg-todo-network-ci'
param location string = 'centralindia'
@minLength(3)
@maxLength(63)
param postgresServerName string
param postgresAdminLogin string = 'todoadmin'
@secure()
param postgresAdminPassword string
@minLength(3)
@maxLength(24)
param keyVaultName string
param postgresSubnetName string = 'snet-postgres'
param postgresPrivateDnsZoneName string = 'todo-platform.postgres.database.azure.com'
param databaseName string = 'todoapp'

resource dataRg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: dataResourceGroupName
}
resource networkRg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: networkResourceGroupName
}
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-todo-platform-ci'
  scope: networkRg
}
resource postgresSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: postgresSubnetName
}
resource privateDns 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: postgresPrivateDnsZoneName
  scope: networkRg
}

module postgres './modules/data/postgres.bicep' = {
  name: 'todo-postgres'
  scope: dataRg
  params: {
    location: location
    serverName: postgresServerName
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    delegatedSubnetId: postgresSubnet.id
    privateDnsZoneId: privateDns.id
    databaseName: databaseName
  }
}
module keyVault './modules/security/key-vault.bicep' = {
  name: 'todo-key-vault'
  scope: dataRg
  params: {
    location: location
    vaultName: keyVaultName
    postgresAdminSecret: postgresAdminPassword
    postgresAdminLogin: postgresAdminLogin
    postgresFqdn: postgres.outputs.fqdn
    databaseName: databaseName
  }
}
output postgresFqdn string = postgres.outputs.fqdn
output keyVaultUri string = keyVault.outputs.vaultUri
