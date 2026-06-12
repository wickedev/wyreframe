-- Recovered from wyreframe-backend D1 (`74509cf6-7f08-46a3-beed-452a580fdccc`)
-- on 2026-06-12 via `wrangler d1 execute DB --remote`.

CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL,
    last_updated INTEGER NOT NULL,
    viewport_state TEXT,
    ascii_content TEXT
);

CREATE TABLE chat_messages (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    timestamp TEXT NOT NULL DEFAULT '',
    metadata TEXT
);

CREATE TABLE exports (
    export_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    r2_key TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
);

CREATE INDEX idx_sessions_last_updated ON sessions(last_updated);
CREATE INDEX idx_chat_messages_session_id ON chat_messages(session_id);
CREATE INDEX idx_chat_messages_timestamp ON chat_messages(timestamp);
CREATE INDEX idx_exports_session_id ON exports(session_id);
CREATE INDEX idx_exports_created_at ON exports(created_at);
