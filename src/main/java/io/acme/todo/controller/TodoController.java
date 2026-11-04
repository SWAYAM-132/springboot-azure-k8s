package io.acme.todo.controller;

import io.acme.todo.dto.CreateTodoRequest;
import io.acme.todo.dto.TodoResponse;
import io.acme.todo.dto.UpdateTodoRequest;
import io.acme.todo.service.TodoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.net.URI;
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
public class TodoController {

    private final TodoService todoService;

    public TodoController(TodoService todoService) {
        this.todoService = todoService;
    }

    @PostMapping
    @Operation(summary = "Create a todo")
    public ResponseEntity<TodoResponse> create(@Valid @RequestBody CreateTodoRequest request) {
        TodoResponse created = todoService.create(request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(created.id())
                .toUri();
        return ResponseEntity.created(location).body(created);
    }

    @GetMapping
    @Operation(summary = "List todos, optionally filtered by completion status")
    public Page<TodoResponse> findAll(
            @RequestParam(required = false) Boolean completed,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC)
            Pageable pageable
    ) {
        return todoService.findAll(completed, pageable);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a todo by ID")
    public TodoResponse findById(@PathVariable Long id) {
        return todoService.findById(id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a todo")
    public TodoResponse update(
            @PathVariable Long id,
            @Valid @RequestBody UpdateTodoRequest request
    ) {
        return todoService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete a todo")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        todoService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
