
# Todo Azure Platform — Network Plan

## Region
Central India

## Virtual Network
Name: vnet-todo-platform-ci
Address space: 10.40.0.0/16

## Subnets

| Subnet | CIDR | Purpose |
|---|---|---|
| snet-aks-nonprod | 10.40.0.0/22 | Nonprod AKS nodes |
| snet-aks-prod | 10.40.4.0/22 | Prod AKS nodes |
| snet-postgres | 10.40.8.0/27 | PostgreSQL Flexible Server |
| snet-private-endpoints | 10.40.9.0/24 | Private endpoints |
| snet-management | 10.40.10.0/24 | Future management resources |

## AKS Overlay Networks

| Cluster | Pod CIDR | Service CIDR | DNS IP |
|---|---|---|---|
| Nonprod | 10.240.0.0/16 | 10.250.0.0/16 | 10.250.0.10 |
| Prod | 10.241.0.0/16 | 10.251.0.0/16 | 10.251.0.10 |

## Security and DNS
- Management NSG attached to management subnet.
- PostgreSQL subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers.
- PostgreSQL private DNS zone: todo-platform.postgres.database.azure.com.
- Private DNS zone linked to platform VNet.
- Key Vault private endpoint in snet-private-endpoints.
- Key Vault private DNS zone: privatelink.vaultcore.azure.net, linked to platform VNet.
- Key Vault public network access is disabled.
- Azure DevOps deployment agents must run in a VNet-connected agent pool.
- No custom AKS subnet deny rules yet.
- No custom UDR or forced tunnelling yet.

## Deferred
- ACR private endpoint and DNS integration.
- AKS-specific network rules.
- NAT Gateway or Azure Firewall decision.
- DNS Private Resolver, if hybrid DNS becomes necessary.
