
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "1.16.0"
    }
  }
}

variable "azuredevops_org_url" {
  type        = string
  description = "Existing Azure DevOps organisation URL."
}

variable "project_name" {
  type    = string
  default = "SpringBoot-Azure-Deployment"
}

variable "approval_user_principal_name" {
  type        = string
  description = "Azure DevOps user who must approve stage and production deployments."
}

provider "azuredevops" {
  org_service_url = var.azuredevops_org_url
  use_cli         = true
}

data "azuredevops_project" "existing" {
  name = var.project_name
}

data "azuredevops_users" "approver" {
  principal_name = var.approval_user_principal_name
}

locals {
  approver_id = one(data.azuredevops_users.approver.users).id
}

# Self-hosted agent pools

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

# Project agent queues

resource "azuredevops_agent_queue" "nonprod" {
  project_id    = data.azuredevops_project.existing.id
  agent_pool_id = azuredevops_agent_pool.nonprod.id
}

resource "azuredevops_agent_queue" "prod" {
  project_id    = data.azuredevops_project.existing.id
  agent_pool_id = azuredevops_agent_pool.prod.id
}

# Pipeline authorization
# Without pipeline_id, all pipelines in this project are authorized.
# Scope these to the deployment pipeline ID when available.

resource "azuredevops_pipeline_authorization" "nonprod_queue" {
  project_id  = data.azuredevops_project.existing.id
  resource_id = azuredevops_agent_queue.nonprod.id
  type        = "queue"
}

resource "azuredevops_pipeline_authorization" "prod_queue" {
  project_id  = data.azuredevops_project.existing.id
  resource_id = azuredevops_agent_queue.prod.id
  type        = "queue"
}

# Deployment environments

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

# Approval checks

resource "azuredevops_check_approval" "stage" {
  project_id            = data.azuredevops_project.existing.id
  target_resource_id    = azuredevops_environment.stage.id
  target_resource_type  = "environment"
  requester_can_approve = false
  approvers             = [local.approver_id]

  instructions = "Approve the validated image promotion into Stage."
  timeout      = 720
}

resource "azuredevops_check_approval" "prod" {
  project_id            = data.azuredevops_project.existing.id
  target_resource_id    = azuredevops_environment.prod.id
  target_resource_type  = "environment"
  requester_can_approve = false
  approvers             = [local.approver_id]

  instructions = "Verify Stage validation and approve production deployment."
  timeout      = 720
}

# Outputs

output "project_id" {
  value = data.azuredevops_project.existing.id
}

output "nonprod_pool_id" {
  value = azuredevops_agent_pool.nonprod.id
}

output "prod_pool_id" {
  value = azuredevops_agent_pool.prod.id
}
