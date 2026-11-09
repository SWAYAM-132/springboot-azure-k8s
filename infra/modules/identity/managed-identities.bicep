targetScope = 'resourceGroup'

@description('Azure region.')
param location string = 'centralindia'

@description('Resource tags.')
param tags object = {}

resource adoIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-todo-ado-ci'
  location: location
  tags: tags
}

output adoIdentityName string = adoIdentity.name
output adoIdentityId string = adoIdentity.id
output adoPrincipalId string = adoIdentity.properties.principalId
output adoClientId string = adoIdentity.properties.clientId
