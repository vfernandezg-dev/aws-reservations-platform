-- System settings and an append-only audit log.

CREATE TABLE IF NOT EXISTS system_settings (
    key_name    VARCHAR(100) PRIMARY KEY,
    value       TEXT NOT NULL,
    description TEXT,
    is_public   BOOLEAN DEFAULT FALSE,
    updated_by  CHAR(36),
    updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (updated_by) REFERENCES user_profiles(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO system_settings (key_name, value, description, is_public) VALUES
    ('COMPANY_NAME',        'Reservations Platform',        'Display name of the business',          TRUE),
    ('CURRENCY',            'USD',                          'Default currency (ISO 4217)',           TRUE),
    ('TAX_PERCENTAGE',      '18',                           'Tax rate applied to quotations',        FALSE),
    ('BOOKING_WINDOW_DAYS', '90',                           'How far ahead reservations can be made', FALSE),
    ('CANCELLATION_POLICY', '{"days":7,"percentage":50}',   'Cancellation policy (JSON)',            TRUE);

CREATE TABLE IF NOT EXISTS audit_logs (
    id         CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id    CHAR(36),
    table_name VARCHAR(100) NOT NULL,
    record_id  VARCHAR(100) NOT NULL COMMENT 'Primary key of the changed row (UUID or INT)',
    action     ENUM('CREATE', 'UPDATE', 'DELETE') NOT NULL,
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45) COMMENT 'IPv4 or IPv6',
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_profiles(id) ON DELETE SET NULL,
    INDEX idx_audit_table_record (table_name, record_id),
    INDEX idx_audit_created (created_at),
    INDEX idx_audit_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Record every change to a system setting.
CREATE TRIGGER IF NOT EXISTS trg_system_settings_audit
AFTER UPDATE ON system_settings
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, table_name, record_id, action, old_values, new_values)
    VALUES (
        NEW.updated_by,
        'system_settings',
        NEW.key_name,
        'UPDATE',
        JSON_OBJECT('value', OLD.value, 'is_public', OLD.is_public, 'description', OLD.description),
        JSON_OBJECT('value', NEW.value, 'is_public', NEW.is_public, 'description', NEW.description)
    );
END;
