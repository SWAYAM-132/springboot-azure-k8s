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
    public TodoResponse create(CreateTodoRequest request) {
        Todo todo = new Todo(request.title(), request.description());
        return toResponse(todoRepository.save(todo));
    }

    @Override
    @Transactional(readOnly = true)
    public Page<TodoResponse> findAll(Boolean completed, Pageable pageable) {
        validateSort(pageable);
        Page<Todo> todos = completed == null
                ? todoRepository.findAll(pageable)
                : todoRepository.findAllByCompleted(completed, pageable);
        return todos.map(TodoServiceImpl::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public TodoResponse findById(Long id) {
        return toResponse(getTodo(id));
    }

    @Override
    public TodoResponse update(Long id, UpdateTodoRequest request) {
        Todo todo = getTodo(id);
        todo.update(request.title(), request.description(), request.completed());
        return toResponse(todoRepository.save(todo));
    }

    @Override
    public void delete(Long id) {
        todoRepository.delete(getTodo(id));
    }

    private Todo getTodo(Long id) {
        return todoRepository.findById(id)
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
