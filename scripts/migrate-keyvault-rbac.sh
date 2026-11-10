#!/usr/bin/env bash
set -euo pipefail

RG="rg-todo-data-ci"
VAULT="kv-todo-ci-springboot"
SUBSCRIPTION="5282ac61-9692-4758-b6cd-1d6a859625a2"

az account set --subscription "$SUBSCRIPTION"

echo "Current Key Vault authorization mode:"
az keyvault show -g "$RG" -n "$VAULT" \
  --query "properties.enableRbacAuthorization" -o tsv

echo
echo "Current access policies (will become inactive when RBAC is enabled):"
az keyvault show -g "$RG" -n "$VAULT" \
  --query "properties.accessPolicies[].{ObjectId:objectId,Permissions:permissions.secrets}" -o table

echo
echo "Current RBAC assignments:"
KV_ID="$(az keyvault show -g "$RG" -n "$VAULT" --query id -o tsv)"
az role assignment list --scope "$KV_ID" --all \
  --query "[].{Role:roleDefinitionName,Principal:principalName,PrincipalId:principalId}" -o table

echo
echo "Precondition: verify the application identity has Key Vault Secrets User"
echo "at the three application-secret scopes created by infra/modules/security/key-vault.bicep."
echo "Do not continue if those assignments are missing."
read -rp "Type ENABLE-RBAC to switch the vault to Azure RBAC: " CONFIRM
[[ "$CONFIRM" == "ENABLE-RBAC" ]]

az keyvault update -g "$RG" -n "$VAULT" --enable-rbac-authorization true

echo "RBAC is enabled. Validate CSI-mounted secrets and application readiness before"
echo "removing old access policies or redundant RBAC assignments."
