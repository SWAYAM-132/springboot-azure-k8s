package io.acme.todo.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateTodoRequest(
        @NotBlank @Size(max = 200) String title,
        @Size(max = 2000) String description
) {
}
