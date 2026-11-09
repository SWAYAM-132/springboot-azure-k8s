package io.acme.todo.controller;

import io.acme.todo.dto.CreateTodoRequest;
import io.acme.todo.dto.TodoResponse;
import io.acme.todo.dto.UpdateTodoRequest;
import io.acme.todo.service.TodoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.net.URI;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/todos")
@Tag(name = "Todos", description = "Create, browse, update, and delete todo tasks")
@SecurityRequirement(name = "bearerAuth")
public class TodoController {

    private final TodoService todoService;

    public TodoController(TodoService todoService) {
        this.todoService = todoService;
    }

    @PostMapping
    @Operation(summary = "Create a todo")
    public ResponseEntity<TodoResponse> create(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CreateTodoRequest request
    ) {
        TodoResponse created = todoService.create(ownerId(jwt), request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(created.id())
                .toUri();
        return ResponseEntity.created(location).body(created);
    }

    @GetMapping
    @Operation(summary = "List todos, optionally filtered by completion status")
    public Page<TodoResponse> findAll(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) Boolean completed,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC)
            Pageable pageable
    ) {
        return todoService.findAll(ownerId(jwt), completed, pageable);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a todo by ID")
    public TodoResponse findById(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id) {
        return todoService.findById(ownerId(jwt), id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a todo")
    public TodoResponse update(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long id,
            @Valid @RequestBody UpdateTodoRequest request
    ) {
        return todoService.update(ownerId(jwt), id, request);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete a todo")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable Long id) {
        todoService.delete(ownerId(jwt), id);
        return ResponseEntity.noContent().build();
    }

    private static String ownerId(Jwt jwt) {
        String tenantId = jwt.getClaimAsString("tid");
        String objectId = jwt.getClaimAsString("oid");
        if (tenantId == null || objectId == null) {
            throw new AccessDeniedException("A Microsoft Entra user identity is required.");
        }
        return tenantId + ":" + objectId;
    }
}
