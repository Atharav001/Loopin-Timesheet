-- Loopin Backend Database Schema & Row-Level Security (RLS)
-- Supports Cross-Device Sync (macOS -> Android -> Web) with strict user isolation.

-- 1. Timesheet Entries Table
CREATE TABLE IF NOT EXISTS public.timesheet_entries (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('planned', 'logged')),
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    raw_text TEXT NOT NULL,
    input_method TEXT NOT NULL CHECK (input_method IN ('typed', 'voice', 'skipped')),
    category TEXT NOT NULL,
    subcategory TEXT,
    productivity TEXT NOT NULL CHECK (productivity IN ('productive', 'neutral', 'wasteful', 'uncategorized')),
    gcal_event_id TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    device_id TEXT NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_entries_user_time ON public.timesheet_entries(user_id, start_at, kind);
CREATE INDEX IF NOT EXISTS idx_entries_user_updated ON public.timesheet_entries(user_id, updated_at);

-- 2. Classification Rules Table
CREATE TABLE IF NOT EXISTS public.classification_rules (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    phrase TEXT NOT NULL,
    category TEXT NOT NULL,
    subcategory TEXT,
    productivity TEXT NOT NULL CHECK (productivity IN ('productive', 'neutral', 'wasteful', 'uncategorized')),
    user_defined BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_phrase UNIQUE (user_id, phrase)
);

CREATE INDEX IF NOT EXISTS idx_rules_user_phrase ON public.classification_rules(user_id, phrase);

-- 3. Calendar Links Table
CREATE TABLE IF NOT EXISTS public.calendar_links (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'google',
    calendar_id_planned TEXT,
    calendar_id_logged TEXT,
    sync_token TEXT,
    account_id TEXT,
    account_email TEXT,
    last_sync_at TIMESTAMPTZ,
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (user_id, provider)
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

-- Enable RLS on all tables
ALTER TABLE public.timesheet_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classification_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_links ENABLE ROW LEVEL SECURITY;

-- Timesheet Entries Policies
CREATE POLICY "Users can only read own timesheet entries"
    ON public.timesheet_entries FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can only insert own timesheet entries"
    ON public.timesheet_entries FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only update own timesheet entries"
    ON public.timesheet_entries FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only delete own timesheet entries"
    ON public.timesheet_entries FOR DELETE
    USING (auth.uid() = user_id);

-- Classification Rules Policies
CREATE POLICY "Users can only read own classification rules"
    ON public.classification_rules FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can only insert own classification rules"
    ON public.classification_rules FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only update own classification rules"
    ON public.classification_rules FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only delete own classification rules"
    ON public.classification_rules FOR DELETE
    USING (auth.uid() = user_id);

-- Calendar Links Policies
CREATE POLICY "Users can only read own calendar links"
    ON public.calendar_links FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can only insert own calendar links"
    ON public.calendar_links FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can only update own calendar links"
    ON public.calendar_links FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
