package io.acme.todo.service;

import io.acme.todo.dto.CreateTodoRequest;
import io.acme.todo.dto.TodoResponse;
import io.acme.todo.dto.UpdateTodoRequest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface TodoService {

    TodoResponse create(String ownerId, CreateTodoRequest request);

    Page<TodoResponse> findAll(String ownerId, Boolean completed, Pageable pageable);

    TodoResponse findById(String ownerId, Long id);

    TodoResponse update(String ownerId, Long id, UpdateTodoRequest request);

    void delete(String ownerId, Long id);
}
