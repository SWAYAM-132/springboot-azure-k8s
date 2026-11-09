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
@minLength(1)
@maxLength(63)
param todoApiDatabaseUsername string = 'todoapp'
@secure()
param todoApiDatabasePassword string
param appIdentityName string = 'id-todo-api-workload-ci'
param appIdentityResourceGroupName string = 'rg-todo-platform-ci'
param postgresSubnetName string = 'snet-postgres'
param privateEndpointsSubnetName string = 'snet-private-endpoints'
param postgresPrivateDnsZoneName string = 'todo-platform.postgres.database.azure.com'
param keyVaultPrivateDnsZoneName string = 'privatelink.vaultcore.azure.net'
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
resource privateEndpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: privateEndpointsSubnetName
}
resource privateDns 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: postgresPrivateDnsZoneName
  scope: networkRg
}
resource keyVaultPrivateDns 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: keyVaultPrivateDnsZoneName
  scope: networkRg
}
resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: appIdentityName
  scope: resourceGroup(appIdentityResourceGroupName)
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
    todoApiDatabaseUsername: todoApiDatabaseUsername
    todoApiDatabasePassword: todoApiDatabasePassword
    appIdentityPrincipalId: appIdentity.properties.principalId
    privateEndpointSubnetId: privateEndpointsSubnet.id
    privateDnsZoneId: keyVaultPrivateDns.id
  }
}
output postgresFqdn string = postgres.outputs.fqdn
output keyVaultUri string = keyVault.outputs.vaultUri
output keyVaultName string = keyVault.outputs.vaultName
output todoApiWorkloadIdentityClientId string = appIdentity.properties.clientId
