targetScope = 'resourceGroup'

param identityName string
param credentialName string
param issuer string
param subject string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

resource credential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: credentialName
  properties: {
    issuer: issuer
    subject: subject
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}
