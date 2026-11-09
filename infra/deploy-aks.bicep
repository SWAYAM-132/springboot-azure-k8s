targetScope = 'subscription'
param deployNonprod bool = true
param deployProd bool = false
param assignNamespaceRoles bool = false
param location string = 'centralindia'
param networkResourceGroupName string = 'rg-todo-network-ci'
param acrResourceGroupName string = 'rg-todo-platform-ci'
param nonprodResourceGroupName string = 'rg-todo-nonprod-ci'
param prodResourceGroupName string = 'rg-todo-prod-ci'
param acrName string = 'acrtodoplatformci'
param adoIdentityName string = 'id-todo-ado-ci'
param prodAdoIdentityName string = 'id-todo-ado-prod-ci'
param appIdentityName string = 'id-todo-api-workload-ci'
param appIdentityResourceGroupName string = 'rg-todo-platform-ci'

resource networkRg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: networkResourceGroupName
}
resource acrRg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: acrResourceGroupName
}
resource nonprodRg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: nonprodResourceGroupName
}
resource prodRg 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: prodResourceGroupName
}
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-todo-platform-ci'
  scope: networkRg
}
resource adoIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: adoIdentityName
  scope: acrRg
}
resource prodAdoIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: prodAdoIdentityName
  scope: acrRg
}
resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: appIdentityName
  scope: resourceGroup(appIdentityResourceGroupName)
}

module nonprod './modules/aks/cluster.bicep' = if (deployNonprod) {
  name: 'aks-todo-nonprod'
  scope: nonprodRg
  params: {
    location: location
    clusterName: 'aks-todo-nonprod-ci'
    dnsPrefix: 'todo-nonprod-ci'
    subnetId: resourceId(networkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-aks-nonprod')
    podCidr: '10.240.0.0/16'
    serviceCidr: '10.250.0.0/16'
    dnsServiceIP: '10.250.0.10'
    acrResourceGroupName: acrResourceGroupName
    acrName: acrName
    adoIdentityPrincipalId: adoIdentity.properties.principalId
    deploymentNamespaces: [
      'todo-dev'
      'todo-stage'
    ]
    assignNamespaceRoles: assignNamespaceRoles
    nodeVmSize: 'Standard_B2s'
    minNodeCount: 1
    maxNodeCount: 2
  }
}
module prod './modules/aks/cluster.bicep' = if (deployProd) {
  name: 'aks-todo-prod'
  scope: prodRg
  params: {
    location: location
    clusterName: 'aks-todo-prod-ci'
    dnsPrefix: 'todo-prod-ci'
    subnetId: resourceId(networkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', vnet.name, 'snet-aks-prod')
    podCidr: '10.241.0.0/16'
    serviceCidr: '10.251.0.0/16'
    dnsServiceIP: '10.251.0.10'
    acrResourceGroupName: acrResourceGroupName
    acrName: acrName
    adoIdentityPrincipalId: prodAdoIdentity.properties.principalId
    deploymentNamespaces: [
      'todo-prod'
    ]
    assignNamespaceRoles: assignNamespaceRoles
    nodeVmSize: 'Standard_D2s_v5'
    minNodeCount: 2
    maxNodeCount: 3
  }
}
module nonprodDevFederation './modules/identity/federated-identity-credential.bicep' = if (deployNonprod) {
  name: 'todo-api-identity-nonprod-dev'
  scope: acrRg
  params: {
    identityName: appIdentity.name
    credentialName: 'aks-todo-nonprod-dev'
    issuer: nonprod!.outputs.oidcIssuerUrl
    subject: 'system:serviceaccount:todo-dev:todo-api'
  }
}
module nonprodStageFederation './modules/identity/federated-identity-credential.bicep' = if (deployNonprod) {
  name: 'todo-api-identity-nonprod-stage'
  scope: acrRg
  params: {
    identityName: appIdentity.name
    credentialName: 'aks-todo-nonprod-stage'
    issuer: nonprod!.outputs.oidcIssuerUrl
    subject: 'system:serviceaccount:todo-stage:todo-api'
  }
}
module prodFederation './modules/identity/federated-identity-credential.bicep' = if (deployProd) {
  name: 'todo-api-identity-prod'
  scope: acrRg
  params: {
    identityName: appIdentity.name
    credentialName: 'aks-todo-prod'
    issuer: prod!.outputs.oidcIssuerUrl
    subject: 'system:serviceaccount:todo-prod:todo-api'
  }
}
output nonprodClusterName string = deployNonprod ? nonprod!.outputs.clusterName : ''
output prodClusterName string = deployProd ? prod!.outputs.clusterName : ''
output workloadIdentityClientId string = appIdentity.properties.clientId
