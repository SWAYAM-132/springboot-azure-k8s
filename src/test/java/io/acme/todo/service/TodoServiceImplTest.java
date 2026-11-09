package io.acme.todo.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import io.acme.todo.common.exception.InvalidSortException;
import io.acme.todo.common.exception.ResourceNotFoundException;
import io.acme.todo.dto.TodoResponse;
import io.acme.todo.entity.Todo;
import io.acme.todo.repository.TodoRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

@ExtendWith(MockitoExtension.class)
class TodoServiceImplTest {

    @Mock
    private TodoRepository todoRepository;

    @InjectMocks
    private TodoServiceImpl todoService;

    @Test
    void findByIdReturnsTodoResponse() {
        Todo todo = new Todo("tenant:user", "Write tests", "Cover service behavior");
        when(todoRepository.findByIdAndOwnerId(1L, "tenant:user")).thenReturn(Optional.of(todo));

        TodoResponse response = todoService.findById("tenant:user", 1L);

        assertEquals("Write tests", response.title());
        assertEquals("Cover service behavior", response.description());
        assertEquals(false, response.completed());
    }

    @Test
    void findByIdThrowsWhenTodoDoesNotExist() {
        when(todoRepository.findByIdAndOwnerId(404L, "tenant:user")).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> todoService.findById("tenant:user", 404L));
    }

    @Test
    void findAllRejectsUnknownSortProperties() {
        PageRequest pageable = PageRequest.of(0, 20, Sort.by("notAProperty"));

        assertThrows(InvalidSortException.class, () -> todoService.findAll("tenant:user", null, pageable));
    }

    @Test
    void deleteRemovesExistingTodo() {
        Todo todo = new Todo("tenant:user", "Delete me", null);
        when(todoRepository.findByIdAndOwnerId(1L, "tenant:user")).thenReturn(Optional.of(todo));

        todoService.delete("tenant:user", 1L);

        verify(todoRepository).delete(todo);
    }
}
