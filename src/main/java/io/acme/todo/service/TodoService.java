package io.acme.todo.service;

import io.acme.todo.dto.CreateTodoRequest;
import io.acme.todo.dto.TodoResponse;
import io.acme.todo.dto.UpdateTodoRequest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface TodoService {

    TodoResponse create(CreateTodoRequest request);

    Page<TodoResponse> findAll(Boolean completed, Pageable pageable);

    TodoResponse findById(Long id);

    TodoResponse update(Long id, UpdateTodoRequest request);

    void delete(Long id);
}
