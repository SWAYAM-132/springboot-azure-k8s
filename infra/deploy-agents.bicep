targetScope = 'subscription'

param location string = 'centralindia'
param networkResourceGroupName string = 'rg-todo-network-ci'
param platformResourceGroupName string = 'rg-todo-platform-ci'
param vnetName string = 'vnet-todo-platform-ci'
param managementSubnetName string = 'snet-management'
param nonprodIdentityName string = 'id-todo-ado-ci'
param prodIdentityName string = 'id-todo-ado-prod-ci'
@secure()
param sshPublicKey string
param vmSize string = 'Standard_B2s_v2'

resource networkRg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: networkResourceGroupName
}
resource platformRg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: platformResourceGroupName
}
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
  scope: networkRg
}
resource managementSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: managementSubnetName
}
resource nonprodIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: nonprodIdentityName
  scope: platformRg
}
resource prodIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: prodIdentityName
  scope: platformRg
}

module nonprodAgent './modules/agent-vm/main.bicep' = {
  name: 'todo-nonprod-agent-vm'
  scope: platformRg
  params: {
    location: location
    vmName: 'vm-todo-ado-nonprod-ci'
    subnetId: managementSubnet.id
    identityResourceId: nonprodIdentity.id
    sshPublicKey: sshPublicKey
    vmSize: vmSize
    tags: {
      project: 'todo-azure-platform'
      environment: 'nonprod'
      managedBy: 'bicep'
      purpose: 'ado-self-hosted-agent'
    }
  }
}
module prodAgent './modules/agent-vm/main.bicep' = {
  name: 'todo-prod-agent-vm'
  scope: platformRg
  params: {
    location: location
    vmName: 'vm-todo-ado-prod-ci'
    subnetId: managementSubnet.id
    identityResourceId: prodIdentity.id
    sshPublicKey: sshPublicKey
    vmSize: vmSize
    tags: {
      project: 'todo-azure-platform'
      environment: 'prod'
      managedBy: 'bicep'
      purpose: 'ado-self-hosted-agent'
    }
  }
}

output nonprodVmId string = nonprodAgent.outputs.vmId
output nonprodPrivateIp string = nonprodAgent.outputs.privateIp
output prodVmId string = prodAgent.outputs.vmId
output prodPrivateIp string = prodAgent.outputs.privateIp
