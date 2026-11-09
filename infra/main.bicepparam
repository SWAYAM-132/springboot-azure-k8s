
using './main.bicep'

param location = 'centralindia'
param projectName = 'todo'

param commonTags = {
  project: 'todo-azure-platform'
  managedBy: 'bicep'
  purpose: 'learning'
  costCategory: 'devops-learning'
  owner: 'platform-engineering'
}
