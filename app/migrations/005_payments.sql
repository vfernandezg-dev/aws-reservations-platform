-- Payment methods and payment transactions.

CREATE TABLE IF NOT EXISTS payment_methods (
    id                        INT PRIMARY KEY AUTO_INCREMENT,
    name                      VARCHAR(50) NOT NULL UNIQUE,
    description               TEXT,
    is_active                 BOOLEAN      DEFAULT TRUE,
    processing_fee_percentage DECIMAL(5,2) DEFAULT 0 CHECK (processing_fee_percentage >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS payments (
    id                    CHAR(36)      PRIMARY KEY,
    reservation_id        CHAR(36)      NOT NULL,
    payment_number        VARCHAR(50)   NOT NULL UNIQUE,
    payment_method_id     INT,
    amount                DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    currency              CHAR(3)       DEFAULT 'USD' COMMENT 'ISO 4217 code',
    payment_type          ENUM('ADVANCE', 'PARTIAL', 'FULL', 'REFUND') NOT NULL,
    transaction_reference VARCHAR(100) COMMENT 'Payment gateway reference',
    status                ENUM('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'REFUNDED') DEFAULT 'PENDING',
    processed_by          CHAR(36),
    payment_date          TIMESTAMP NULL,
    notes                 TEXT,
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (reservation_id)    REFERENCES reservations(id)    ON DELETE RESTRICT,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (processed_by)      REFERENCES user_profiles(id)   ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO payment_methods (name, description, processing_fee_percentage) VALUES
    ('CARD',          'Credit or debit card', 3.50),
    ('BANK_TRANSFER', 'Bank transfer',        0.00),
    ('CASH',          'Cash at the venue',    0.00);
