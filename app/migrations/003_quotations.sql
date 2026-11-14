-- Quotations sent to clients before a reservation is confirmed.

CREATE TABLE IF NOT EXISTS quotations (
    id               CHAR(36)      PRIMARY KEY,
    client_id        CHAR(36)      NOT NULL,
    quotation_number VARCHAR(50)   NOT NULL UNIQUE,
    event_type       VARCHAR(100),
    event_date       DATE,
    estimated_guests INT           CHECK (estimated_guests > 0),
    total_amount     DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
    discount_amount  DECIMAL(10,2) DEFAULT 0 CHECK (discount_amount >= 0),
    tax_amount       DECIMAL(10,2) DEFAULT 0 CHECK (tax_amount >= 0),
    final_amount     DECIMAL(10,2) NOT NULL CHECK (final_amount >= 0),
    status           ENUM('DRAFT', 'SENT', 'APPROVED', 'REJECTED', 'EXPIRED') DEFAULT 'DRAFT',
    valid_until      DATE,
    notes            TEXT,
    created_by       CHAR(36),
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id)  REFERENCES user_profiles(id) ON DELETE RESTRICT,
    FOREIGN KEY (created_by) REFERENCES user_profiles(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS quotation_details (
    id           INT PRIMARY KEY AUTO_INCREMENT,
    quotation_id CHAR(36)      NOT NULL,
    item_type    ENUM('SERVICE', 'PACKAGE') NOT NULL,
    item_id      INT           NOT NULL COMMENT 'services.id or packages.id',
    quantity     INT           DEFAULT 1 CHECK (quantity > 0),
    unit_price   DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    total_price  DECIMAL(10,2) NOT NULL CHECK (total_price >= 0),
    notes        TEXT,
    FOREIGN KEY (quotation_id) REFERENCES quotations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
