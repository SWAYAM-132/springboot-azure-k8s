
targetScope = 'resourceGroup'

@description('Azure region for networking resources.')
param location string = 'centralindia'

@description('Private DNS zone used by PostgreSQL Flexible Servers.')
param postgresPrivateDnsZoneName string = 'todo-platform.postgres.database.azure.com'
@description('Private DNS zone for Key Vault private endpoints.')
param keyVaultPrivateDnsZoneName string = 'privatelink.vaultcore.azure.net'
@description('Private DNS zone for Azure Container Registry private endpoints.')
param acrPrivateDnsZoneName string = 'privatelink.azurecr.io'

var vnetName = 'vnet-todo-platform-ci'
var vnetAddressSpace = '10.40.0.0/16'

resource managementNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-todo-management-ci'
  location: location
  properties: {
    securityRules: []
  }
}

resource platformVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'snet-aks-nonprod'
        properties: {
          addressPrefix: '10.40.0.0/22'
        }
      }
      {
        name: 'snet-aks-prod'
        properties: {
          addressPrefix: '10.40.4.0/22'
        }
      }
      {
        name: 'snet-postgres'
        properties: {
          addressPrefix: '10.40.8.0/27'
          delegations: [
            {
              name: 'postgres-flexible-server-delegation'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: '10.40.9.0/24'
        }
      }
      {
        name: 'snet-management'
        properties: {
          addressPrefix: '10.40.10.0/24'
          networkSecurityGroup: {
            id: managementNsg.id
          }
        }
      }
    ]
  }
}

resource postgresPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: postgresPrivateDnsZoneName
  location: 'global'
}

resource postgresDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: postgresPrivateDnsZone
  name: 'link-todo-platform-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: platformVnet.id
    }
    registrationEnabled: false
  }
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: keyVaultPrivateDnsZoneName
  location: 'global'
}

resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: acrPrivateDnsZoneName
  location: 'global'
}

resource acrDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZone
  name: 'link-todo-platform-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: platformVnet.id
    }
    registrationEnabled: false
  }
}

resource keyVaultDnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultPrivateDnsZone
  name: 'link-todo-platform-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: platformVnet.id
    }
    registrationEnabled: false
  }
}

output vnetName string = platformVnet.name
output vnetId string = platformVnet.id
output vnetAddressSpace string = vnetAddressSpace
output nonprodSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-aks-nonprod')
output prodSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-aks-prod')
output postgresSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-postgres')
output privateEndpointsSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-private-endpoints')
output managementSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'snet-management')
output managementNsgId string = managementNsg.id
output postgresPrivateDnsZoneId string = postgresPrivateDnsZone.id
output keyVaultPrivateDnsZoneId string = keyVaultPrivateDnsZone.id
output acrPrivateDnsZoneId string = acrPrivateDnsZone.id
