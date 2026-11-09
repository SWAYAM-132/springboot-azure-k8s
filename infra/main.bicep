
targetScope = 'subscription'

@description('Azure region for the platform.')
param location string = 'centralindia'

@description('Project identifier.')
param projectName string = 'todo'

@description('Common tags applied to all platform resource groups.')
param commonTags object = {
  project: 'todo-azure-platform'
  managedBy: 'bicep'
  purpose: 'learning'
  costCategory: 'devops-learning'
}

var resourceGroupDefinitions = [
  {
    name: 'rg-${projectName}-platform-ci'
    purpose: 'Shared platform services'
    environment: 'shared'
  }
  {
    name: 'rg-${projectName}-network-ci'
    purpose: 'Networking and private DNS'
    environment: 'shared'
  }
  {
    name: 'rg-${projectName}-nonprod-ci'
    purpose: 'Non-production AKS'
    environment: 'nonprod'
  }
  {
    name: 'rg-${projectName}-prod-ci'
    purpose: 'Production AKS'
    environment: 'prod'
  }
  {
    name: 'rg-${projectName}-data-ci'
    purpose: 'PostgreSQL databases'
    environment: 'shared'
  }
  {
    name: 'rg-${projectName}-observability-ci'
    purpose: 'Monitoring and logging'
    environment: 'shared'
  }
]

resource resourceGroups 'Microsoft.Resources/resourceGroups@2024-03-01' = [
  for rg in resourceGroupDefinitions: {
    name: rg.name
    location: location
    tags: union(commonTags, {
      purpose: rg.purpose
      environment: rg.environment
    })
  }
]

module networking './modules/networking/vnet.bicep' = {
  name: 'todo-network-foundation'
  scope: resourceGroup('rg-${projectName}-network-ci')
  params: {
    location: location
    postgresPrivateDnsZoneName: 'todo-platform.postgres.database.azure.com'
  }
  dependsOn: [
    resourceGroups
  ]
}

module containerRegistry './modules/container-registry/acr.bicep' = {
  name: 'todo-container-registry'
  scope: resourceGroup('rg-${projectName}-platform-ci')
  params: {
    acrName: 'acrtodoplatformci'
    location: location
    acrSku: 'Basic'
    tags: commonTags
  }
  dependsOn: [
    resourceGroups
  ]
}

module managedIdentities './modules/identity/managed-identities.bicep' = {
  name: 'todo-managed-identities'
  scope: resourceGroup('rg-todo-platform-ci')
  params: {
    location: location
    tags: commonTags
  }
  dependsOn: [
    resourceGroups
  ]
}

module acrPushRoleAssignment './modules/identity/role-assignments.bicep' = {
  name: 'todo-acr-push-permission'
  scope: resourceGroup('rg-todo-platform-ci')
  params: {
    acrName: 'acrtodoplatformci'
    principalId: managedIdentities.outputs.adoPrincipalId
  }
}

output createdResourceGroupNames array = [
  for (rg, i) in resourceGroupDefinitions: resourceGroups[i].name
]
