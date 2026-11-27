-- OSADI Foreign Worker System: core tables (Step 2)
-- Additive only: creates a new "fw" schema and new tables. Touches nothing that exists.
-- Safe to run more than once (IF NOT EXISTS everywhere).

CREATE SCHEMA IF NOT EXISTS fw;

-- Client companies the workers work for (e.g. MMP, MMY)
CREATE TABLE IF NOT EXISTS fw.employers (
    id              BIGSERIAL PRIMARY KEY,
    name            TEXT NOT NULL,
    code            TEXT UNIQUE,
    contact_name    TEXT,
    contact_email   TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One row per foreign worker (not linked to the ATS)
CREATE TABLE IF NOT EXISTS fw.workers (
    id               BIGSERIAL PRIMARY KEY,
    full_name        TEXT NOT NULL,
    gender           TEXT NOT NULL CHECK (gender IN ('MALE', 'FEMALE')),
    nationality      TEXT,
    phone            TEXT,
    passport_no      TEXT NOT NULL,
    passport_expiry  DATE,
    permit_no        TEXT,
    permit_expiry    DATE,
    employer_id      BIGINT NOT NULL REFERENCES fw.employers(id),
    hired_date       DATE,
    status           TEXT NOT NULL DEFAULT 'ACTIVE'
                     CHECK (status IN ('ACTIVE', 'RESIGNED', 'ABSCONDED', 'COMPLETED')),
    exit_date        DATE,
    exit_reason      TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- same dedupe rule as PassPort Pro: name + passport number
    UNIQUE (full_name, passport_no)
);

-- Hostels; each belongs to one company
CREATE TABLE IF NOT EXISTS fw.properties (
    id           BIGSERIAL PRIMARY KEY,
    name         TEXT NOT NULL,
    address      TEXT,
    employer_id  BIGINT NOT NULL REFERENCES fw.employers(id),
    capacity     INTEGER,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Rooms are gender-based
CREATE TABLE IF NOT EXISTS fw.rooms (
    id           BIGSERIAL PRIMARY KEY,
    property_id  BIGINT NOT NULL REFERENCES fw.properties(id),
    room_no      TEXT NOT NULL,
    floor        TEXT,
    gender       TEXT NOT NULL CHECK (gender IN ('MALE', 'FEMALE')),
    capacity     INTEGER,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (property_id, room_no)
);

CREATE TABLE IF NOT EXISTS fw.beds (
    id         BIGSERIAL PRIMARY KEY,
    room_id    BIGINT NOT NULL REFERENCES fw.rooms(id),
    bed_label  TEXT NOT NULL,
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (room_id, bed_label)
);

-- Check-in / move-out history. A move closes the old row and opens a new one; rows are never edited otherwise.
-- checked_in_by / checked_out_by become links to the users table in Step 4.
CREATE TABLE IF NOT EXISTS fw.bed_assignments (
    id               BIGSERIAL PRIMARY KEY,
    worker_id        BIGINT NOT NULL REFERENCES fw.workers(id),
    bed_id           BIGINT NOT NULL REFERENCES fw.beds(id),
    check_in_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    checked_in_by    BIGINT NOT NULL,
    check_out_at     TIMESTAMPTZ,
    checked_out_by   BIGINT,
    move_out_reason  TEXT,
    CHECK (check_out_at IS NULL OR check_out_at >= check_in_at)
);

-- Only one current occupant per bed, and one current bed per worker
CREATE UNIQUE INDEX IF NOT EXISTS ux_bed_assignments_open_bed
    ON fw.bed_assignments (bed_id) WHERE check_out_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_bed_assignments_open_worker
    ON fw.bed_assignments (worker_id) WHERE check_out_at IS NULL;

-- Who did what, when. Append-only: the app only ever inserts here.
CREATE TABLE IF NOT EXISTS fw.events (
    id             BIGSERIAL PRIMARY KEY,
    entity_type    TEXT NOT NULL,
    entity_id      BIGINT NOT NULL,
    action         TEXT NOT NULL,
    actor_user_id  BIGINT,
    at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    before         JSONB,
    after          JSONB,
    note           TEXT
);

CREATE INDEX IF NOT EXISTS ix_events_entity ON fw.events (entity_type, entity_id);
