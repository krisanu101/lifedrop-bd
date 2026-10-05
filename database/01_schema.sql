-- =====================================================================
-- LifeDrop BD - Blood Donation Management System
-- Core Schema: tables, constraints, indexes
-- =====================================================================

CREATE DATABASE IF NOT EXISTS lifedrop_bd;
USE lifedrop_bd;

-- ---------------------------------------------------------------------
-- USERS  (both donors and admins log in through this table)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    phone         VARCHAR(20) NOT NULL,
    role          ENUM('donor', 'admin') NOT NULL DEFAULT 'donor',
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- DONORS  (1-to-1 extension of users where role = 'donor')
-- ---------------------------------------------------------------------
CREATE TABLE donors (
    donor_id          INT PRIMARY KEY,               -- same as users.user_id
    blood_group       ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    gender            ENUM('Male','Female','Other') NOT NULL,
    age               INT NOT NULL CHECK (age BETWEEN 18 AND 65),
    area              VARCHAR(80) NOT NULL,
    district          VARCHAR(80) NOT NULL DEFAULT 'Dhaka',
    last_donation_date DATE NULL,
    total_donations   INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_donor_user FOREIGN KEY (donor_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- BLOOD BANKS
-- ---------------------------------------------------------------------
CREATE TABLE blood_banks (
    bank_id     INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(120) NOT NULL,
    area        VARCHAR(80) NOT NULL,
    district    VARCHAR(80) NOT NULL DEFAULT 'Dhaka',
    contact     VARCHAR(20) NOT NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- INVENTORY  (units of each blood group available at each bank)
-- ---------------------------------------------------------------------
CREATE TABLE inventory (
    inventory_id    INT AUTO_INCREMENT PRIMARY KEY,
    bank_id         INT NOT NULL,
    blood_group     ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    units_available INT NOT NULL DEFAULT 0 CHECK (units_available >= 0),
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_inventory_bank FOREIGN KEY (bank_id) REFERENCES blood_banks(bank_id) ON DELETE CASCADE,
    UNIQUE KEY uq_bank_group (bank_id, blood_group)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- DONATIONS  (a completed donation event)
-- ---------------------------------------------------------------------
CREATE TABLE donations (
    donation_id     INT AUTO_INCREMENT PRIMARY KEY,
    donor_id        INT NOT NULL,
    bank_id         INT NOT NULL,
    donation_date   DATE NOT NULL DEFAULT (CURRENT_DATE),
    units           INT NOT NULL DEFAULT 1 CHECK (units > 0),
    CONSTRAINT fk_donation_donor FOREIGN KEY (donor_id) REFERENCES donors(donor_id) ON DELETE CASCADE,
    CONSTRAINT fk_donation_bank  FOREIGN KEY (bank_id)  REFERENCES blood_banks(bank_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- BLOOD REQUESTS
-- ---------------------------------------------------------------------
CREATE TABLE blood_requests (
    request_id       INT AUTO_INCREMENT PRIMARY KEY,
    requested_by      INT NULL,                       -- users.user_id, NULL if requested by a guest
    requester_name    VARCHAR(100) NOT NULL,
    requester_phone   VARCHAR(20) NOT NULL,
    blood_group       ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    units_needed      INT NOT NULL CHECK (units_needed > 0),
    hospital          VARCHAR(150) NOT NULL,
    bank_id           INT NULL,
    urgency           ENUM('normal','emergency') NOT NULL DEFAULT 'normal',
    status            ENUM('pending','approved','rejected','fulfilled') NOT NULL DEFAULT 'pending',
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at       TIMESTAMP NULL,
    CONSTRAINT fk_request_user FOREIGN KEY (requested_by) REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT fk_request_bank FOREIGN KEY (bank_id) REFERENCES blood_banks(bank_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- BLOOD COMPATIBILITY (lookup table: which donor group can give to which recipient group)
-- ---------------------------------------------------------------------
CREATE TABLE blood_compatibility (
    donor_group     ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    recipient_group ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    PRIMARY KEY (donor_group, recipient_group)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- AUDIT LOG (who changed what, when — filled automatically by triggers)
-- ---------------------------------------------------------------------
CREATE TABLE audit_log (
    log_id       INT AUTO_INCREMENT PRIMARY KEY,
    table_name   VARCHAR(50) NOT NULL,
    action       VARCHAR(20) NOT NULL,
    record_id    INT NOT NULL,
    details      VARCHAR(255),
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- INDEXES (fast search by the fields users search on most)
-- ---------------------------------------------------------------------
CREATE INDEX idx_donors_blood_group ON donors(blood_group);
CREATE INDEX idx_donors_area        ON donors(area);
CREATE INDEX idx_inventory_group    ON inventory(blood_group);
CREATE INDEX idx_requests_status    ON blood_requests(status);
CREATE INDEX idx_requests_group     ON blood_requests(blood_group);
