#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION="5282ac61-9692-4758-b6cd-1d6a859625a2"
VAULT_ID="/subscriptions/${SUBSCRIPTION}/resourceGroups/rg-todo-data-ci/providers/Microsoft.KeyVault/vaults/kv-todo-ci-springboot"

# id-todo-ado-ci: no pipeline Key Vault reads after removal of the variable group.
ADO_CI_PRINCIPAL="750915ee-bc6a-4e34-8b1a-f410b059a277"
# sc-todo-data-kv-ci service principal: legacy Key Vault Library connection.
LEGACY_KV_SC_PRINCIPAL="b19f8c73-e5e4-454f-8e1a-21168e9540bb"

az account set --subscription "$SUBSCRIPTION"

echo "This removes only redundant Key Vault RBAC grants for the two listed principals."
echo "It deliberately preserves the application workload identity's secret-scoped grants"
echo "and preserves the unknown app registration principal c0c971ae-... for investigation."
read -rp "Type REMOVE-LEGACY-KV-ACCESS to continue: " CONFIRM
[[ "$CONFIRM" == "REMOVE-LEGACY-KV-ACCESS" ]]

for PRINCIPAL in "$ADO_CI_PRINCIPAL" "$LEGACY_KV_SC_PRINCIPAL"; do
  az role assignment list --assignee "$PRINCIPAL" --scope "$VAULT_ID" --all -o json \
    | jq -r '.[] | select(
        .roleDefinitionName == "Key Vault Secrets Officer" or
        .roleDefinitionName == "Key Vault Secrets User" or
        .roleDefinitionName == "Key Vault Reader" or
        .roleDefinitionName == "Key Vault Data Access Administrator"
      ) | .id' \
    | while IFS= read -r ASSIGNMENT_ID; do
        [[ -n "$ASSIGNMENT_ID" ]] || continue
        az role assignment delete --ids "$ASSIGNMENT_ID"
      done
done

echo "Removed legacy Key Vault RBAC grants for id-todo-ado-ci and sc-todo-data-kv-ci."
echo "Do not delete the old access policies until RBAC-mode application and CSI tests pass."
