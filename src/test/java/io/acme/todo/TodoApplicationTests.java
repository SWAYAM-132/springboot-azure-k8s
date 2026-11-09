package io.acme.todo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                "management.endpoint.health.probes.enabled=true",
                "management.endpoint.health.group.readiness.include=readinessState,db"
        })
@AutoConfigureMockMvc
@ActiveProfiles("test")
class TodoApplicationTests {

    @Autowired
    private MockMvc mockMvc;

    @LocalServerPort
    private int port;

    @Test
    void contextLoads() {
    }

    @Test
    void openApiDocumentIncludesTodoRoutes() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paths['/api/todos']").exists())
                .andExpect(jsonPath("$.paths['/api/todos/{id}']").exists())
                .andExpect(jsonPath("$.components.securitySchemes.bearerAuth.scheme").value("bearer"));
    }

    @Test
    void todoApiRejectsUnauthenticatedRequests() throws Exception {
        mockMvc.perform(get("/api/todos"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void todoRecordsAreIsolatedByEntraUser() throws Exception {
        var created = mockMvc.perform(post("/api/todos")
                        .with(jwt().jwt(token -> token.claim("tid", "tenant-a").claim("oid", "user-a")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Private task"
                                }
                                """))
                .andExpect(status().isCreated())
                .andReturn();
        Number todoId = com.jayway.jsonpath.JsonPath.read(
                created.getResponse().getContentAsString(), "$.id");

        mockMvc.perform(get("/api/todos/" + todoId.longValue())
                        .with(jwt().jwt(token -> token.claim("tid", "tenant-b").claim("oid", "user-b"))))
                .andExpect(status().isNotFound());

        mockMvc.perform(get("/api/todos")
                        .with(jwt().jwt(token -> token.claim("tid", "tenant-b").claim("oid", "user-b"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void todoOwnerCanUpdateAndDeleteTodo() throws Exception {
        var owner = jwt().jwt(token -> token.claim("tid", "tenant-crud").claim("oid", "user-crud"));
        var created = mockMvc.perform(post("/api/todos")
                        .with(owner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Original"
                                }
                                """))
                .andExpect(status().isCreated())
                .andReturn();
        Number todoId = com.jayway.jsonpath.JsonPath.read(
                created.getResponse().getContentAsString(), "$.id");
        String path = "/api/todos/" + todoId.longValue();

        mockMvc.perform(put(path)
                        .with(owner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated",
                                  "completed": true
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Updated"))
                .andExpect(jsonPath("$.completed").value(true));

        mockMvc.perform(delete(path).with(owner))
                .andExpect(status().isNoContent());
        mockMvc.perform(get(path).with(owner))
                .andExpect(status().isNotFound());
    }

    @Test
    void todoApiReturnsNotFoundForUnknownIdsAndRejectsInvalidSort() throws Exception {
        var owner = jwt().jwt(token -> token.claim("tid", "tenant-query").claim("oid", "user-query"));
        mockMvc.perform(get("/api/todos/9223372036854775807").with(owner))
                .andExpect(status().isNotFound());
        mockMvc.perform(get("/api/todos?sort=notAProperty").with(owner))
                .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/todos?page=10000&size=100").with(owner))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0));
    }

    @Test
    void actuatorHealthProbesReturnUpOverHttp() throws Exception {
        HttpClient client = HttpClient.newHttpClient();
        for (String probe : new String[] { "liveness", "readiness" }) {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("http://localhost:" + port + "/actuator/health/" + probe))
                    .GET()
                    .build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

            assertEquals(200, response.statusCode(), probe + " probe response");
            assertTrue(response.body().contains("\"status\":\"UP\""), probe + " probe health");
        }
    }

    @Test
    void invalidCreateRequestReturnsStructuredBadRequest() throws Exception {
        mockMvc.perform(post("/api/todos")
                        .with(jwt().jwt(token -> token.claim("tid", "test-tenant").claim("oid", "test-user")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "   ",
                                  "description": "invalid title"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.path").value("/api/todos"));
    }
}
