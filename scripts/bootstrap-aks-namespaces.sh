#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION="5282ac61-9692-4758-b6cd-1d6a859625a2"
NONPROD_RG="rg-todo-nonprod-ci"
PROD_RG="rg-todo-prod-ci"
NONPROD_CLUSTER="aks-todo-nonprod-ci"
PROD_CLUSTER="aks-todo-prod-ci"
NONPROD_PRINCIPAL="750915ee-bc6a-4e34-8b1a-f410b059a277"
PROD_PRINCIPAL="6532046a-cf35-46d1-97cf-b424a9f7a0a9"
AKS_RBAC_WRITER_ROLE="5b999177-9696-4545-85c7-50de3797e5a1"

# Run as an administrator with cluster-admin access and permission to create
# role assignments. This is a one-time bootstrap, not a pipeline job.
az account set --subscription "$SUBSCRIPTION"

az aks get-credentials -g "$NONPROD_RG" -n "$NONPROD_CLUSTER" --admin --overwrite-existing
kubectl apply -f k8s/overlays/dev/namespace.yaml
kubectl apply -f k8s/overlays/stage/namespace.yaml

for NS in todo-dev todo-stage; do
  SCOPE="/subscriptions/$SUBSCRIPTION/resourceGroups/$NONPROD_RG/providers/Microsoft.ContainerService/managedClusters/$NONPROD_CLUSTER/namespaces/$NS"
  EXISTS="$(az role assignment list --assignee "$NONPROD_PRINCIPAL" --scope "$SCOPE" --all --query "[?roleDefinitionId=='/subscriptions/$SUBSCRIPTION/providers/Microsoft.Authorization/roleDefinitions/$AKS_RBAC_WRITER_ROLE'] | length(@)" -o tsv)"
  if [[ "$EXISTS" == "0" ]]; then
    az role assignment create --assignee-object-id "$NONPROD_PRINCIPAL" \
      --assignee-principal-type ServicePrincipal --role "$AKS_RBAC_WRITER_ROLE" --scope "$SCOPE" -o none
  fi
done

az aks get-credentials -g "$PROD_RG" -n "$PROD_CLUSTER" --admin --overwrite-existing
kubectl apply -f k8s/overlays/prod/namespace.yaml

SCOPE="/subscriptions/$SUBSCRIPTION/resourceGroups/$PROD_RG/providers/Microsoft.ContainerService/managedClusters/$PROD_CLUSTER/namespaces/todo-prod"
EXISTS="$(az role assignment list --assignee "$PROD_PRINCIPAL" --scope "$SCOPE" --all --query "[?roleDefinitionId=='/subscriptions/$SUBSCRIPTION/providers/Microsoft.Authorization/roleDefinitions/$AKS_RBAC_WRITER_ROLE'] | length(@)" -o tsv)"
if [[ "$EXISTS" == "0" ]]; then
  az role assignment create --assignee-object-id "$PROD_PRINCIPAL" \
    --assignee-principal-type ServicePrincipal --role "$AKS_RBAC_WRITER_ROLE" --scope "$SCOPE" -o none
fi

echo "Namespaces created and namespace-scoped deployment permissions reconciled."
