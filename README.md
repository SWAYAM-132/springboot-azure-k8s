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

To run the application against PostgreSQL, provide `DB_URL`, `DB_USERNAME`,
and `DB_PASSWORD` in a `.env` file in the project root. Spring Boot loads this
file when starting from the project directory. The file is gitignored; do not
commit database credentials. You can also set these values as environment
variables:

```sh
export DB_URL=jdbc:postgresql://localhost:5432/java_demo
export DB_USERNAME=your_database_user
export DB_PASSWORD=your_database_password
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
