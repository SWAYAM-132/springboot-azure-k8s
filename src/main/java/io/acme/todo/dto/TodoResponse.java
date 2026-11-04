package io.acme.todo.dto;

import java.time.Instant;

public record TodoResponse(
        Long id,
        String title,
        String description,
        boolean completed,
        Instant createdAt,
        Instant updatedAt
) {
}
