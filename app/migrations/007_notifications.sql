-- Notification templates, sent notifications and internal staff messages.

CREATE TABLE IF NOT EXISTS notification_templates (
    id            INT PRIMARY KEY AUTO_INCREMENT,
    name          VARCHAR(100) NOT NULL UNIQUE,
    type          ENUM('EMAIL', 'SMS', 'PUSH', 'IN_APP') NOT NULL,
    subject       VARCHAR(200),
    template_body TEXT NOT NULL,
    variables     JSON COMMENT 'Placeholders available to the template',
    is_active     BOOLEAN   DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notifications (
    id            CHAR(36) PRIMARY KEY,
    recipient_id  CHAR(36) NOT NULL,
    template_id   INT,
    type          ENUM('EMAIL', 'SMS', 'PUSH', 'IN_APP') NOT NULL,
    subject       VARCHAR(200),
    message       TEXT NOT NULL,
    status        ENUM('PENDING', 'SENT', 'DELIVERED', 'FAILED') DEFAULT 'PENDING',
    sent_at       TIMESTAMP NULL,
    delivered_at  TIMESTAMP NULL,
    error_message TEXT,
    metadata      JSON COMMENT 'Delivery details (email, phone, ...)',
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (recipient_id) REFERENCES user_profiles(id)          ON DELETE CASCADE,
    FOREIGN KEY (template_id)  REFERENCES notification_templates(id) ON DELETE SET NULL,
    INDEX idx_notifications_recipient (recipient_id),
    INDEX idx_notifications_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS internal_messages (
    id           CHAR(36) PRIMARY KEY,
    sender_id    CHAR(36) NOT NULL,
    recipient_id CHAR(36) NOT NULL,
    subject      VARCHAR(200),
    message      TEXT NOT NULL,
    priority     ENUM('LOW', 'NORMAL', 'HIGH', 'URGENT') DEFAULT 'NORMAL',
    is_read      BOOLEAN DEFAULT FALSE,
    read_at      TIMESTAMP NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id)    REFERENCES user_profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (recipient_id) REFERENCES user_profiles(id) ON DELETE CASCADE,
    INDEX idx_internal_messages_recipient (recipient_id, is_read),
    INDEX idx_internal_messages_sender (sender_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
