ALTER TABLE todos ADD COLUMN owner_id VARCHAR(80);

UPDATE todos SET owner_id = 'unassigned';

ALTER TABLE todos ALTER COLUMN owner_id SET NOT NULL;

CREATE INDEX idx_todos_owner_id ON todos (owner_id);
