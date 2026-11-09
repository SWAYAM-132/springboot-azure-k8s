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

## Run and explore

The task management UI is available at `/`. Use it to create tasks, look up
tasks by their generated IDs, edit or mark them complete, and delete them.

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
├── base/
└── overlays/
    ├── dev/     # 1 replica, smaller resources, todo-nonprod
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

Deploy PostgreSQL and Key Vault using a local secure parameters file
`infra/data.local.bicepparam` (ignored by Git):

```bicep
using './deploy-data.bicep'
param postgresServerName = 'todo-pg-unique-lowercase-name'
param keyVaultName = 'kv-todo-unique-name'
param postgresAdminLogin = 'todoadmin'
param postgresAdminPassword = 'USE-A-STRONG-PASSWORD'
```

```sh
az deployment sub what-if --location centralindia --parameters infra/data.local.bicepparam
az deployment sub create --name todo-data --location centralindia --parameters infra/data.local.bicepparam
```

Deploy the nonprod cluster:

```sh
az deployment sub what-if --location centralindia --template-file infra/deploy-aks.bicep --parameters deployNonprod=true deployProd=false
az deployment sub create --name todo-aks-nonprod --location centralindia --template-file infra/deploy-aks.bicep --parameters deployNonprod=true deployProd=false
```

Production AKS is opt-in and incurs additional cost:

```sh
az deployment sub what-if --location centralindia --template-file infra/deploy-aks.bicep --parameters deployNonprod=false deployProd=true
```

PostgreSQL is private to the VNet; connect through a VNet-connected host or VPN.
Before deploying the application, create a least-privilege app database role and
provide a Kubernetes Secret named `todo-api-db` in each target namespace
(`todo-dev`, `todo-stage`, and `todo-prod`), with keys `DB_URL`,
`DB_USERNAME`, and `DB_PASSWORD`. Never commit these credentials. The base
Deployment maps this Secret to Spring's standard `SPRING_DATASOURCE_*`
environment variables, so all overlays use the same Secret name. CSI Secrets
Store with Workload Identity is a follow-up integration.

### CI/CD

Configure Azure Pipelines to use `azure-pipelines.yml` and authorize the
`sc-todo-platform-acr-ci` service connection for ACR and both AKS clusters.
Branches `dev` and `stage` deploy their corresponding Kustomize overlays to
nonprod AKS; `release` deploys the prod overlay to prod AKS. Each build runs
Maven verification and publishes the image tagged with the full Git commit SHA.
The deployment stage applies that image transformation with `kubectl apply -k`
and verifies the requested replicas are ready.

Configure an approval check on the Azure DevOps environment `todo-prod` before
enabling production deployments. Environment approvals are configured in Azure
DevOps, not in this YAML file. Pull requests run tests but do not publish or
deploy images.
