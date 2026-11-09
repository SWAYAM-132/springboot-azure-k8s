package io.acme.todo.service;

import io.acme.todo.common.exception.InvalidSortException;
import io.acme.todo.common.exception.ResourceNotFoundException;
import io.acme.todo.dto.CreateTodoRequest;
import io.acme.todo.dto.TodoResponse;
import io.acme.todo.dto.UpdateTodoRequest;
import io.acme.todo.entity.Todo;
import io.acme.todo.repository.TodoRepository;
import java.util.Set;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class TodoServiceImpl implements TodoService {

    private static final Set<String> SORTABLE_PROPERTIES =
            Set.of("id", "title", "completed", "createdAt", "updatedAt");

    private final TodoRepository todoRepository;

    public TodoServiceImpl(TodoRepository todoRepository) {
        this.todoRepository = todoRepository;
    }

    @Override
    public TodoResponse create(String ownerId, CreateTodoRequest request) {
        Todo todo = new Todo(ownerId, request.title(), request.description());
        return toResponse(todoRepository.save(todo));
    }

    @Override
    @Transactional(readOnly = true)
    public Page<TodoResponse> findAll(String ownerId, Boolean completed, Pageable pageable) {
        validateSort(pageable);
        Page<Todo> todos = completed == null
                ? todoRepository.findAllByOwnerId(ownerId, pageable)
                : todoRepository.findAllByOwnerIdAndCompleted(ownerId, completed, pageable);
        return todos.map(TodoServiceImpl::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public TodoResponse findById(String ownerId, Long id) {
        return toResponse(getTodo(ownerId, id));
    }

    @Override
    public TodoResponse update(String ownerId, Long id, UpdateTodoRequest request) {
        Todo todo = getTodo(ownerId, id);
        todo.update(request.title(), request.description(), request.completed());
        return toResponse(todoRepository.save(todo));
    }

    @Override
    public void delete(String ownerId, Long id) {
        todoRepository.delete(getTodo(ownerId, id));
    }

    private Todo getTodo(String ownerId, Long id) {
        return todoRepository.findByIdAndOwnerId(id, ownerId)
                .orElseThrow(() -> new ResourceNotFoundException("Todo", id));
    }

    private static void validateSort(Pageable pageable) {
        pageable.getSort().forEach(order -> {
            if (!SORTABLE_PROPERTIES.contains(order.getProperty())) {
                throw new InvalidSortException(order.getProperty());
            }
        });
    }

    private static TodoResponse toResponse(Todo todo) {
        return new TodoResponse(
                todo.getId(),
                todo.getTitle(),
                todo.getDescription(),
                todo.isCompleted(),
                todo.getCreatedAt(),
                todo.getUpdatedAt()
        );
    }
}
