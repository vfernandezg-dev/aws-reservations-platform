-- Users & roles. Authentication lives in Amazon Cognito; this table stores the
-- business profile linked to the Cognito user (sub claim).

CREATE TABLE IF NOT EXISTS user_profiles (
    id                CHAR(36)     PRIMARY KEY,
    cognito_user_id   VARCHAR(255) NOT NULL UNIQUE,
    user_type         ENUM('CLIENT', 'ADMIN', 'STAFF') NOT NULL,
    first_name        VARCHAR(100) NOT NULL,
    last_name         VARCHAR(100) NOT NULL,
    phone             VARCHAR(20),
    date_of_birth     DATE,
    address           TEXT,
    emergency_contact VARCHAR(100),
    emergency_phone   VARCHAR(20),
    is_active         BOOLEAN   DEFAULT TRUE,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS roles (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    permissions JSON COMMENT 'Permission list as JSON',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_roles (
    user_id     CHAR(36) NOT NULL,
    role_id     INT      NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_by CHAR(36),
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id)     REFERENCES user_profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id)     REFERENCES roles(id)         ON DELETE CASCADE,
    FOREIGN KEY (assigned_by) REFERENCES user_profiles(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO roles (name, description, permissions) VALUES
    ('ADMIN',   'Full administrative access',          JSON_ARRAY('*')),
    ('MANAGER', 'Manages reservations and staff',      JSON_ARRAY('reservations:*', 'staff:read', 'reports:read')),
    ('STAFF',   'Operates assigned events and shifts', JSON_ARRAY('reservations:read', 'schedules:read'));
