param location string
param clusterName string
param dnsPrefix string
param subnetId string
param podCidr string
param serviceCidr string
param dnsServiceIP string
param acrResourceGroupName string
param acrName string
param adoIdentityPrincipalId string
param deploymentNamespaces array
param assignNamespaceRoles bool = false
param nodeVmSize string = 'Standard_B2s'
param minNodeCount int = 1
param maxNodeCount int = 2

var acrPullRoleGuid = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var aksClusterUserRoleGuid = '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
var aksRbacWriterRoleGuid = '5b999177-9696-4545-85c7-50de3797e5a1'

resource aks 'Microsoft.ContainerService/managedClusters@2026-05-01' = {
  name: clusterName
  location: location
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    enableRBAC: true
    disableLocalAccounts: true
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      imageCleaner: {
        enabled: true
        intervalHours: 168
      }
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
      }
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      podCidr: podCidr
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: minNodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetId
        enableAutoScaling: true
        minCount: minNodeCount
        maxCount: maxNodeCount
        maxPods: 50
        osDiskSizeGB: 64
        scaleDownMode: 'Delete'
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
    }
  }
}

module acrPull './acr-role.bicep' = {
  name: 'acr-pull-role'
  scope: resourceGroup(acrResourceGroupName)
  params: {
    acrName: acrName
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    roleDefinitionGuid: acrPullRoleGuid
  }
}

resource aksClusterUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, adoIdentityPrincipalId, aksClusterUserRoleGuid)
  scope: aks
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', aksClusterUserRoleGuid)
    principalId: adoIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource deploymentNamespacesInAks 'Microsoft.ContainerService/managedClusters/namespaces@2024-05-01' existing = [
  for namespace in deploymentNamespaces: {
    parent: aks
    name: namespace
  }
]

resource aksRbacWriters 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (namespace, i) in deploymentNamespaces: if (assignNamespaceRoles) {
    name: guid(deploymentNamespacesInAks[i].id, adoIdentityPrincipalId, aksRbacWriterRoleGuid)
    scope: deploymentNamespacesInAks[i]
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', aksRbacWriterRoleGuid)
      principalId: adoIdentityPrincipalId
      principalType: 'ServicePrincipal'
    }
  }
]

output clusterName string = aks.name
output clusterId string = aks.id
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
output kubeletObjectId string = aks.properties.identityProfile.kubeletidentity.objectId
