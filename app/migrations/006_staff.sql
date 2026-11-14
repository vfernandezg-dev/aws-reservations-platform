-- Staff shifts, schedules and evaluations (depends on 004_reservations).
-- Trigger bodies need no DELIMITER: the migration runner sends each file as a
-- multi-statement query and the server parses BEGIN ... END blocks itself.

CREATE TABLE IF NOT EXISTS work_shifts (
    id         INT PRIMARY KEY AUTO_INCREMENT,
    name       VARCHAR(50) NOT NULL,
    start_time TIME        NOT NULL,
    end_time   TIME        NOT NULL,
    is_active  BOOLEAN DEFAULT TRUE,
    CONSTRAINT chk_shift_times CHECK (start_time < end_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS staff_schedules (
    id             CHAR(36) PRIMARY KEY,
    staff_id       CHAR(36) NOT NULL,
    reservation_id CHAR(36),
    shift_id       INT,
    work_date      DATE     NOT NULL,
    start_time     TIME,
    end_time       TIME,
    status         ENUM('SCHEDULED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'ABSENT') DEFAULT 'SCHEDULED',
    assigned_by    CHAR(36),
    notes          TEXT,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (staff_id)       REFERENCES user_profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (reservation_id) REFERENCES reservations(id)  ON DELETE SET NULL,
    FOREIGN KEY (shift_id)       REFERENCES work_shifts(id)   ON DELETE SET NULL,
    FOREIGN KEY (assigned_by)    REFERENCES user_profiles(id) ON DELETE SET NULL,
    INDEX idx_schedules_staff_date (staff_id, work_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Copy start/end time from the shift and reject inverted time ranges.
CREATE TRIGGER IF NOT EXISTS trg_staff_schedules_set_times
BEFORE INSERT ON staff_schedules
FOR EACH ROW
BEGIN
    IF NEW.shift_id IS NOT NULL THEN
        SELECT start_time, end_time INTO @shift_start, @shift_end
        FROM work_shifts WHERE id = NEW.shift_id;

        SET NEW.start_time = @shift_start;
        SET NEW.end_time = @shift_end;
    END IF;

    IF NEW.start_time IS NOT NULL AND NEW.end_time IS NOT NULL AND NEW.start_time >= NEW.end_time THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'start_time must be earlier than end_time';
    END IF;
END;

CREATE TABLE IF NOT EXISTS staff_evaluations (
    id              CHAR(36) PRIMARY KEY,
    staff_id        CHAR(36) NOT NULL,
    evaluator_id    CHAR(36) NOT NULL,
    reservation_id  CHAR(36),
    rating          TINYINT  NOT NULL,
    feedback        TEXT,
    evaluation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (staff_id)       REFERENCES user_profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (evaluator_id)   REFERENCES user_profiles(id) ON DELETE RESTRICT,
    FOREIGN KEY (reservation_id) REFERENCES reservations(id)  ON DELETE SET NULL,
    -- A CHECK constraint replaces the two legacy validation triggers.
    CONSTRAINT chk_evaluation_rating CHECK (rating BETWEEN 1 AND 5),
    INDEX idx_evaluations_staff (staff_id),
    INDEX idx_evaluations_date (evaluation_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
