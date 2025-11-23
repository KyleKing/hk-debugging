-- PostgreSQL initialization script for local development
-- This runs automatically when the PostgreSQL container starts

-- Create development database (already created by POSTGRES_DB env var)
-- CREATE DATABASE dev;

-- Connect to development database
\c dev;

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "hstore";

-- Create example schema
CREATE SCHEMA IF NOT EXISTS app;

-- Create example tables (customize for your application)

-- Users table
CREATE TABLE IF NOT EXISTS app.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sessions table
CREATE TABLE IF NOT EXISTS app.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES app.users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Example application data table
CREATE TABLE IF NOT EXISTS app.posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES app.users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    published BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON app.users(email);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON app.sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON app.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON app.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_published ON app.posts(published);

-- Insert seed data for development
INSERT INTO app.users (id, email, username, password_hash)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'admin@example.com', 'admin', crypt('password123', gen_salt('bf'))),
    ('22222222-2222-2222-2222-222222222222', 'user1@example.com', 'user1', crypt('password123', gen_salt('bf'))),
    ('33333333-3333-3333-3333-333333333333', 'user2@example.com', 'user2', crypt('password123', gen_salt('bf')))
ON CONFLICT (email) DO NOTHING;

INSERT INTO app.posts (user_id, title, content, published)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'Welcome Post', 'This is a sample post for local development.', true),
    ('22222222-2222-2222-2222-222222222222', 'Draft Post', 'This is a draft post.', false)
ON CONFLICT DO NOTHING;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION app.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at trigger to tables
DROP TRIGGER IF EXISTS update_users_updated_at ON app.users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON app.users
    FOR EACH ROW
    EXECUTE FUNCTION app.update_updated_at_column();

DROP TRIGGER IF EXISTS update_posts_updated_at ON app.posts;
CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE ON app.posts
    FOR EACH ROW
    EXECUTE FUNCTION app.update_updated_at_column();

-- Grant permissions (for local development, grant all)
GRANT ALL PRIVILEGES ON SCHEMA app TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO postgres;

-- Display initialization complete message
DO $$
BEGIN
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'PostgreSQL initialization complete!';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Database: dev';
    RAISE NOTICE 'Schema: app';
    RAISE NOTICE 'Sample users created:';
    RAISE NOTICE '  - admin@example.com (password: password123)';
    RAISE NOTICE '  - user1@example.com (password: password123)';
    RAISE NOTICE '  - user2@example.com (password: password123)';
    RAISE NOTICE '=================================================';
END $$;
