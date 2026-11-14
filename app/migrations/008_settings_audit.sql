-- System settings and an append-only audit log.

CREATE TABLE IF NOT EXISTS system_settings (
    key_name    VARCHAR(100) PRIMARY KEY,
    value       TEXT        NOT NULL,
    description TEXT,
    is_public   BOOLEAN     NOT NULL DEFAULT FALSE,
    updated_by  UUID        REFERENCES user_profiles(id) ON DELETE SET NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE TRIGGER trg_system_settings_updated_at
    BEFORE UPDATE ON system_settings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO system_settings (key_name, value, description, is_public) VALUES
    ('COMPANY_NAME',        'Reservations Platform',      'Display name of the business',           TRUE),
    ('CURRENCY',            'USD',                        'Default currency (ISO 4217)',            TRUE),
    ('TAX_PERCENTAGE',      '18',                         'Tax rate applied to quotations',         FALSE),
    ('BOOKING_WINDOW_DAYS', '90',                         'How far ahead reservations can be made', FALSE),
    ('CANCELLATION_POLICY', '{"days":7,"percentage":50}', 'Cancellation policy (JSON)',             TRUE)
ON CONFLICT (key_name) DO NOTHING;

CREATE TABLE IF NOT EXISTS audit_logs (
    id         UUID         PRIMARY KEY DEFAULT uuidv7(),
    user_id    UUID         REFERENCES user_profiles(id) ON DELETE SET NULL,
    table_name VARCHAR(100) NOT NULL,
    record_id  TEXT         NOT NULL,  -- primary key of the changed row (UUID or integer)
    action     TEXT         NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_table_record ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_created      ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_user         ON audit_logs(user_id);

-- Record every change to a system setting.
CREATE OR REPLACE FUNCTION system_settings_audit() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_logs (user_id, table_name, record_id, action, old_values, new_values)
    VALUES (
        NEW.updated_by,
        'system_settings',
        NEW.key_name,
        'UPDATE',
        jsonb_build_object('value', OLD.value, 'is_public', OLD.is_public, 'description', OLD.description),
        jsonb_build_object('value', NEW.value, 'is_public', NEW.is_public, 'description', NEW.description)
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_system_settings_audit
    AFTER UPDATE ON system_settings
    FOR EACH ROW EXECUTE FUNCTION system_settings_audit();
