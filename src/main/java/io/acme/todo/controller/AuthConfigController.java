package io.acme.todo.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AuthConfigController {

    private final String tenantId;
    private final String clientId;
    private final String apiScope;

    public AuthConfigController(
            @Value("${todo.auth.tenant-id:}") String tenantId,
            @Value("${todo.auth.client-id:}") String clientId,
            @Value("${todo.auth.api-scope:}") String apiScope
    ) {
        this.tenantId = tenantId;
        this.clientId = clientId;
        this.apiScope = apiScope;
    }

    @GetMapping("/api/auth/config")
    public AuthConfig config() {
        return new AuthConfig(tenantId, clientId, apiScope);
    }

    public record AuthConfig(String tenantId, String clientId, String apiScope) {
    }
}
