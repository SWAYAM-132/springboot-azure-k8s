# Todo List API

A layered REST API built with Spring Boot, Spring Data JPA, PostgreSQL, request
validation, and OpenAPI/Swagger UI.

## Package and folder structure

The root package is `io.acme.todo`. Java packages mirror the source folders,
and Spring Boot component scanning starts here so the application discovers all
subpackages automatically:

```text
src/main/java/io/acme/todo/
├── TodoApplication.java
├── common/exception/       Shared API error types and handlers
├── controller/             HTTP routes and status codes
├── dto/                    Validated request and response models
├── entity/                 JPA model mapped to PostgreSQL
├── repository/             Database queries
└── service/                Business logic and transactions
```

In Java, `io.acme.todo` corresponds to `io/acme/todo` on disk. A package
name is not an endpoint URL: it organizes classes and determines component
scanning. The API routes are defined separately by `@RequestMapping`.

Keep `TodoApplication` at the root package so Spring Boot discovers all
subpackages. Replace `io.acme.todo` with your own reverse-domain package if
`io.acme` is not a namespace you control.

## API endpoints

Base path: `/api/todos`

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/todos` | Create a task |
| `GET` | `/api/todos` | List tasks with pagination and sorting |
| `GET` | `/api/todos/{id}` | Retrieve a task |
| `PUT` | `/api/todos/{id}` | Update a task |
| `DELETE` | `/api/todos/{id}` | Delete a task |

List query parameters include `completed` (`true` or `false`), `page` (zero
based), `size` (maximum 100), and `sort` (for example `createdAt,desc`). Only
`id`, `title`, `completed`, `createdAt`, and `updatedAt` are sortable.

Create request:

```json
{
  "title": "Plan the week",
  "description": "Review deadlines and appointments"
}
```

Update request:

```json
{
  "title": "Plan the week",
  "description": "Review deadlines and appointments",
  "completed": true
}
```

Invalid requests return `400`; unknown IDs return `404`. Create returns `201`
with a `Location` header, and delete returns `204`.

All `/api/todos` routes require a Microsoft Entra ID bearer token. The API
validates the configured tenant issuer and audience and scopes every todo to
the token's `tid` and `oid` claims. A user cannot read, update, or delete
another user's todos; an inaccessible ID returns `404`.

## Run and explore

The task management UI is available at `/` and signs in with Microsoft Entra
ID. Register a single-tenant API application that exposes a delegated
`access_as_user` scope, and a single-page application registration that is
allowed to request that scope. Configure the API's audience, tenant ID, SPA
client ID, and full scope name as described below.

To run the application against PostgreSQL, provide the standard Spring
datasource environment variables. Do not store credentials in source control:

```sh
export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/java_demo
export SPRING_DATASOURCE_USERNAME=your_database_user
export SPRING_DATASOURCE_PASSWORD=your_database_password
export SPRING_DATASOURCE_DRIVER_CLASS_NAME=org.postgresql.Driver
export SPRING_JPA_HIBERNATE_DDL_AUTO=validate
export SPRING_JPA_OPEN_IN_VIEW=false
export SPRING_DATA_WEB_PAGEABLE_MAX_PAGE_SIZE=100
export SPRING_FLYWAY_BASELINE_ON_MIGRATE=true
export SPRING_FLYWAY_BASELINE_VERSION=0
export TODO_ENTRA_TENANT_ID=your-tenant-id
export TODO_API_AUDIENCE=api://your-api-application-id
export TODO_ENTRA_SPA_CLIENT_ID=your-spa-application-id
export TODO_API_SCOPE=api://your-api-application-id/access_as_user
./mvnw spring-boot:run
```

Tests use an in-memory H2 database and do not require PostgreSQL:

```sh
./mvnw test
```

Flyway applies versioned schema migrations from
`src/main/resources/db/migration`. Hibernate validates the schema at startup
instead of changing it automatically.

Swagger UI is available at [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html)
and the OpenAPI JSON is at [http://localhost:8080/v3/api-docs](http://localhost:8080/v3/api-docs).

## Azure platform deployment

The Azure deployment assets live alongside the application:

```text
infra/
├── main.bicep                 # Resource groups, VNet, ACR and CI identity
├── deploy-data.bicep          # Private PostgreSQL and Key Vault
├── deploy-aks.bicep           # Nonprod AKS by default; production is opt-in
└── modules/
    ├── aks/
    ├── container-registry/
    ├── data/
    ├── identity/
    ├── networking/
    └── security/
k8s/
├── base/        # Shared resources; environment namespaces are declared by overlays
└── overlays/
    ├── dev/     # 1 replica, smaller resources, todo-dev
    ├── stage/   # 2 replicas, medium resources, todo-stage
    └── prod/    # 3 replicas, larger resources, todo-prod
pipelines/templates/
└── deploy-overlay.yml
scripts/deployment/
└── .gitkeep
```

### Provision the platform

Log in to Azure and register providers if needed:

```sh
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.DBforPostgreSQL
az provider register --namespace Microsoft.KeyVault
```

Provision shared networking, ACR, identities, and resource groups:

```sh
az deployment sub what-if --location centralindia --parameters infra/main.bicepparam
az deployment sub create --name todo-platform --location centralindia --parameters infra/main.bicepparam
```

`main.bicep` intentionally provisions only the shared foundation (resource
groups, VNet/DNS, ACR, and managed identities). PostgreSQL/Key Vault and AKS
remain separate deployments so their costs and production creation are
explicitly controlled.

Deploy PostgreSQL and Key Vault using a local secure parameters file
`infra/data.local.bicepparam` (ignored by Git):

```bicep
using './deploy-data.bicep'
param postgresServerName = 'todo-pg-unique-lowercase-name'
param keyVaultName = 'kv-todo-unique-name'
param postgresAdminLogin = 'todoadmin'
param postgresAdminPassword = 'USE-A-STRONG-PASSWORD'
param todoApiDatabaseUsername = 'todoapp'
param todoApiDatabasePassword = 'USE-A-DIFFERENT-STRONG-PASSWORD'
```

The Key Vault is reachable through a private endpoint only. Run this deployment
from a VNet-connected host/agent. Its private DNS zone is linked to the platform
VNet. The app-specific database credentials are stored separately from the
PostgreSQL administrator credentials.

```sh
az deployment sub what-if --location centralindia --parameters infra/data.local.bicepparam
az deployment sub create --name todo-data --location centralindia --parameters infra/data.local.bicepparam
```

Deploy the nonprod cluster:

```sh
az deployment sub what-if --location centralindia --template-file infra/deploy-aks.bicep --parameters deployNonprod=true deployProd=false
az deployment sub create --name todo-aks-nonprod --location centralindia --template-file infra/deploy-aks.bicep --parameters deployNonprod=true deployProd=false assignNamespaceRoles=false
```

Production AKS is opt-in and incurs additional cost:

```sh
az deployment sub what-if --location centralindia --template-file infra/deploy-aks.bicep --parameters deployNonprod=false deployProd=true
```

For each new cluster, first create the cluster with `assignNamespaceRoles=false`,
then bootstrap its namespaces as an administrator. Re-run the same deployment
with `assignNamespaceRoles=true` after those namespaces exist; this assigns the
AKS RBAC Writer role at namespace scope. Use `deployNonprod=false
deployProd=true assignNamespaceRoles=false` for the first production deployment,
then repeat with `assignNamespaceRoles=true` after bootstrapping `todo-prod`.
Production creation remains opt-in.

Both clusters enable OIDC, Workload Identity, and the Key Vault CSI add-on.
The deployment creates federated credentials for the app identity and grants
it `Key Vault Secrets User` only on the three application database secret
resources (not the administrator credentials). The CSI driver syncs
`todo-api-db-url`, `todo-api-db-username`, and `todo-api-db-password` into the
namespace-local `todo-api-db` Secret used by the Deployment. No database
credentials belong in Kubernetes manifests or source control.

The app database login is intentionally distinct from the server administrator.
Using a VNet-connected PostgreSQL client, create the role named by
`todoApiDatabaseUsername` with the same password supplied as
`todoApiDatabasePassword`, then grant it only the access needed by the app:

```sql
CREATE ROLE todoapp LOGIN PASSWORD '<same value as todoApiDatabasePassword>';
GRANT CONNECT ON DATABASE todoapp TO todoapp;
```

Connect to the `todoapp` database as the administrator and run:

```sql
GRANT USAGE, CREATE ON SCHEMA public TO todoapp;
```

Flyway runs migrations as this role, so it needs schema DDL privileges. Existing
todo rows are marked `unassigned` by the ownership migration and are not exposed
to any user; backfill them deliberately if preserving access to legacy rows is
required.

After creating AKS, bootstrap the namespaces once using an administrator with
cluster access. `AKS RBAC Writer` is assigned to the pipeline identities only
at the corresponding namespace scopes; it cannot create namespaces:

```sh
kubectl apply -f k8s/overlays/dev/namespace.yaml
kubectl apply -f k8s/overlays/stage/namespace.yaml
kubectl apply -f k8s/overlays/prod/namespace.yaml
```

Apply the first two to nonprod AKS and the last to prod AKS. The writer role
still permits broad operations (including reading namespace Secrets and running
pods as namespace service accounts), so treat each pipeline identity as
privileged within its assigned namespace. Production uses a separate identity.

### CI/CD

Configure Azure Pipelines to use `azure-pipelines.yml`, and create the variable
group `todo-platform-auth` with these non-secret values:

| Variable | Value |
|---|---|
| `entraTenantId` | Single Entra tenant ID |
| `entraSpaClientId` | SPA application/client ID |
| `todoApiAudience` | API application audience (for example `api://<api-client-id>`) |
| `todoApiScope` | Full delegated scope (for example `api://<api-client-id>/access_as_user`) |
| `workloadIdentityClientId` | `todoApiWorkloadIdentityClientId` output from `deploy-aks.bicep` |
| `keyVaultName` | The deployed Key Vault name |

Create the Azure DevOps self-hosted agent pool `todo-vnet-agent` with an agent
that can reach the private endpoints. Install Azure CLI, `kubectl`, `kubelogin`,
and `envsubst` on that agent. Configure the Azure Resource Manager service
connection `sc-todo-platform-acr-ci` to use the `id-todo-ado-ci` identity; it
needs ACR push plus dev/stage namespace deployment access. Configure a separate
`sc-todo-platform-prod-ci` service connection using `id-todo-ado-prod-ci` for
production. Use the `adoAcrIdentityClientId`, `adoProdIdentityClientId`, and
`todoApiWorkloadIdentityClientId` outputs from the Bicep deployments when
configuring the service connections and pipeline variable group. Use workload
identity federation rather than client secrets.

Only `dev` triggers a build. A run verifies the commit, publishes its immutable
ACR digest, and deploys that exact digest in order to dev, stage, then prod.
Configure Azure DevOps approval checks on the `todo-stage` and `todo-prod`
environments; the prod check is the release approval gate. Branches named
`stage` and `release` no longer independently rebuild images. Pull requests run
verification but do not publish or deploy.

## Private VNet Azure DevOps agents (feature/private-vnet-agents)

The private-agent implementation is intentionally staged. It reuses the existing
VNet, management subnet, managed identities, AKS clusters, Key Vault and ACR.

### 1. Create the private ACR endpoint and DNS

The shared networking module now creates and links `privatelink.azurecr.io`.
The ACR module upgrades the existing registry to Premium and creates its
private endpoint. Public access remains enabled during initial validation.

Review first:

```sh
az deployment sub what-if --location centralindia \
  --parameters infra/main.bicepparam

az deployment sub create --name todo-private-acr \
  --location centralindia --parameters infra/main.bicepparam
```

After agent VMs are online and private DNS resolution/push/pull have been
verified, disable ACR public access:

```sh
az deployment sub what-if --location centralindia \
  --parameters infra/main.bicepparam disableAcrPublicNetworkAccess=true

az deployment sub create --name todo-private-acr-lockdown \
  --location centralindia --parameters infra/main.bicepparam \
  disableAcrPublicNetworkAccess=true
```

### 2. Deploy two self-hosted agent VMs

Generate or use an SSH key pair; pass only its public key to Bicep:

```sh
az deployment sub what-if --location centralindia \
  --template-file infra/deploy-agents.bicep \
  --parameters sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)"

az deployment sub create --name todo-ado-agents \
  --location centralindia --template-file infra/deploy-agents.bicep \
  --parameters sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)"
```

The VMs have no public IP. They use the existing management subnet and
separate user-assigned identities. The NSG currently has no custom rules, so
Azure default outbound rules apply; inbound is not opened.

### 3. Create Azure DevOps pools/environments

Terraform in `platform/` creates the two organisation-level pools, project
queues, environments, and Stage/Prod approval checks. The Terraform bootstrap uses the signed-in Azure CLI identity (no PAT or
service connection). The signed-in user must have permission to manage the
project's agent pools and environments.

```sh
cd platform
terraform init
export AZDO_ORG_SERVICE_URL="https://dev.azure.com/swayam-cloud-lab"
export TF_VAR_azuredevops_org_url="$AZDO_ORG_SERVICE_URL"
export TF_VAR_approval_user_principal_name="<ADO approver sign-in>"
az login
terraform plan
terraform apply
```

Terraform uses the Azure CLI signed-in identity. No PAT is stored in Terraform
state or passed to the provider.

### 4. Register each VM agent

SSH through an approved jump host/VPN or Azure Bastion; the VM has no public IP.
Run `scripts/install-ado-agent.sh` as the `azureagent` user with:

- nonprod VM: `ADO_ORG_URL=https://dev.azure.com/swayam-cloud-lab`,
  `ADO_AGENT_POOL=todo-vnet-agent-nonprod`
- prod VM: `ADO_ORG_URL=https://dev.azure.com/swayam-cloud-lab`,
  `ADO_AGENT_POOL=todo-vnet-agent-prod`

The script uses Entra device-code authentication. Complete the displayed
device login in your browser with an account that is an administrator of the
target agent pool. No PAT or client secret is stored on the VM. This
registration identity is used only to register the agent; pipeline jobs use
the VM's attached managed identity for Azure resource access.

### 5. Bootstrap namespaces and namespace-scoped AKS permissions

Run `scripts/bootstrap-aks-namespaces.sh` from an administrator workstation
with cluster-admin access and permission to create Azure role assignments.
This creates the three namespaces and grants the matching pipeline identity
AKS RBAC Writer only within its environment namespace(s).

### 6. Key Vault RBAC migration

The deployed vault currently has access-policy mode enabled even though the
repository's Key Vault module declares RBAC mode. Before switching, verify the
application identity has Key Vault Secrets User at the three application
secret scopes (the existing Bicep module defines these assignments).

Run `scripts/migrate-keyvault-rbac.sh` from a network-connected host with
permission to update the vault. Validate CSI secret mounts and app readiness.
Only then run `scripts/cleanup-legacy-keyvault-rbac.sh` to remove the
redundant Key Vault grants for the old nonprod ADO identity and obsolete
Key Vault service-connection principal. Unknown app-registration grants are
deliberately preserved pending ownership confirmation.

### 7. Pipeline behavior

`azure-pipelines.yml` no longer references an Azure service connection or
variable group. Maven verification of pull requests runs on a Microsoft-hosted
agent so untrusted PR code never runs on a VM with managed identity. Image
build/push and deployments run on the isolated private VNet agents using
`az login --identity`.

Replace the Entra SPA/API placeholders in the YAML with the confirmed
application registration values before deploying. The workload identity client
ID, tenant ID, subscription ID and Key Vault name are non-secret configuration
in the YAML. The application reads its DB credentials directly through AKS
Workload Identity + Key Vault CSI; the pipeline does not fetch Key Vault
secrets.

The first deployment uses the ACR private endpoint while public access remains
enabled. Disable public access only after both agent VMs resolve the registry
to its private IP and a push/pull test succeeds.
