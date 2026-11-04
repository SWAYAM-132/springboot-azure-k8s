package io.acme.todo.common.exception;

public class InvalidSortException extends RuntimeException {

    public InvalidSortException(String property) {
        super("Sorting by '" + property + "' is not supported");
    }
}
