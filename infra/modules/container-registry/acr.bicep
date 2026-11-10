targetScope = 'resourceGroup'

@description('Globally unique Azure Container Registry name.')
param acrName string

@description('Azure region.')
param location string = 'centralindia'

@description('Registry SKU. Private Link requires Premium.')
@allowed([
  'Premium'
])
param acrSku string = 'Premium'

@description('Subnet ID for the registry private endpoint.')
param privateEndpointSubnetId string

@description('Private DNS zone ID for privatelink.azurecr.io.')
param privateDnsZoneId string

@description('Disable public network access only after private connectivity has been verified.')
param disablePublicNetworkAccess bool = false

@description('Resource tags.')
param tags object = {}

resource registry 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  tags: tags
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    dataEndpointEnabled: true
    encryption: {
      status: 'disabled'
    }
    publicNetworkAccess: disablePublicNetworkAccess ? 'Disabled' : 'Enabled'
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${acrName}-private-endpoint'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${acrName}-connection'
        properties: {
          privateLinkServiceId: registry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
  dependsOn: [
    registry
  ]
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'acr-private-dns'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output registryName string = registry.name
output loginServer string = registry.properties.loginServer
output registryId string = registry.id
output privateEndpointId string = privateEndpoint.id
