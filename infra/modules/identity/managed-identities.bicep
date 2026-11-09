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

resource todoApiIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-todo-api-workload-ci'
  location: location
  tags: tags
}

resource adoProdIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-todo-ado-prod-ci'
  location: location
  tags: tags
}

output adoIdentityName string = adoIdentity.name
output adoIdentityId string = adoIdentity.id
output adoPrincipalId string = adoIdentity.properties.principalId
output adoClientId string = adoIdentity.properties.clientId
output todoApiIdentityName string = todoApiIdentity.name
output todoApiIdentityId string = todoApiIdentity.id
output todoApiPrincipalId string = todoApiIdentity.properties.principalId
output todoApiClientId string = todoApiIdentity.properties.clientId
output adoProdIdentityName string = adoProdIdentity.name
output adoProdPrincipalId string = adoProdIdentity.properties.principalId
output adoProdClientId string = adoProdIdentity.properties.clientId
