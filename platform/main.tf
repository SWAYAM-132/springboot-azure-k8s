terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.11"
    }
  }
}

variable "azuredevops_org_url" {
  type        = string
  description = "Existing Azure DevOps organisation URL."
}

variable "azuredevops_pat" {
  type        = string
  sensitive   = true
  description = "Bootstrap PAT used only by Terraform to manage agent pools and environments."
}

variable "project_name" {
  type    = string
  default = "SpringBoot-Azure-Deployment"
}

provider "azuredevops" {
  org_service_url       = var.azuredevops_org_url
  personal_access_token = var.azuredevops_pat
}

data "azuredevops_project" "existing" {
  name = var.project_name
}

resource "azuredevops_agent_pool" "nonprod" {
  name           = "todo-vnet-agent-nonprod"
  auto_provision = false
  auto_update    = true
}

resource "azuredevops_agent_pool" "prod" {
  name           = "todo-vnet-agent-prod"
  auto_provision = false
  auto_update    = true
}

resource "azuredevops_environment" "dev" {
  project_id = data.azuredevops_project.existing.id
  name       = "todo-dev"
}

resource "azuredevops_environment" "stage" {
  project_id = data.azuredevops_project.existing.id
  name       = "todo-stage"
}

resource "azuredevops_environment" "prod" {
  project_id = data.azuredevops_project.existing.id
  name       = "todo-prod"
}

output "project_id" {
  value = data.azuredevops_project.existing.id
}

output "nonprod_pool_id" {
  value = azuredevops_agent_pool.nonprod.id
}

output "prod_pool_id" {
  value = azuredevops_agent_pool.prod.id
}
