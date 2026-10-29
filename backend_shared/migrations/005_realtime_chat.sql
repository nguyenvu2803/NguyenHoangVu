CREATE TABLE IF NOT EXISTS chat_messages (
  id bigserial PRIMARY KEY,
  client_message_id uuid NOT NULL,
  sender_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  recipient_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  body text NOT NULL CHECK (length(body) BETWEEN 1 AND 2000),
  source_language text NOT NULL CHECK (source_language IN ('vi','en','zh')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(sender_id, client_message_id),
  CHECK (sender_id <> recipient_id)
);
CREATE INDEX IF NOT EXISTS chat_sender_recipient_idx ON chat_messages(sender_id, recipient_id, id);
CREATE INDEX IF NOT EXISTS chat_recipient_sender_idx ON chat_messages(recipient_id, sender_id, id);
