# ==========================================
# Stage 1: Build
# ==========================================
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /workspace

# Copy Maven configuration first for better layer caching
COPY pom.xml .
COPY .mvn/ .mvn/
COPY mvnw .

RUN chmod +x mvnw

# Download dependencies
RUN ./mvnw -B dependency:go-offline

# Copy application source
COPY src ./src

# Build and run tests
RUN ./mvnw -B clean package

# ==========================================
# Stage 2: Runtime
# ==========================================
FROM eclipse-temurin:21-jre

WORKDIR /app

# Create non-root user
RUN groupadd --system --gid 10001 appgroup \
    && useradd --system \
    --uid 10001 \
    --gid appgroup \
    --home-dir /app \
    --shell /usr/sbin/nologin \
    appuser

# Copy executable JAR from build stage
COPY --from=build --chown=10001:10001 \
    /workspace/target/todo-api-0.0.1-SNAPSHOT.jar \
    app.jar

# Application configuration
ENV SERVER_PORT=8080

EXPOSE 8080

USER 10001:10001

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
