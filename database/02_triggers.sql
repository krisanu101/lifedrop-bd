-- =====================================================================
-- LifeDrop BD - Triggers
-- =====================================================================
USE lifedrop_bd;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1) When a donation is recorded:
--    - add the units to that bank's inventory (create the row if missing)
--    - update the donor's last_donation_date and total_donations
--    - write an audit log entry
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_after_donation_insert
AFTER INSERT ON donations
FOR EACH ROW
BEGIN
    INSERT INTO inventory (bank_id, blood_group, units_available)
    SELECT NEW.bank_id, d.blood_group, NEW.units
    FROM donors d WHERE d.donor_id = NEW.donor_id
    ON DUPLICATE KEY UPDATE units_available = units_available + NEW.units;

    UPDATE donors
    SET last_donation_date = NEW.donation_date,
        total_donations = total_donations + 1
    WHERE donor_id = NEW.donor_id;

    INSERT INTO audit_log (table_name, action, record_id, details)
    VALUES ('donations', 'INSERT', NEW.donation_id,
            CONCAT('Donor #', NEW.donor_id, ' donated ', NEW.units, ' unit(s) at bank #', NEW.bank_id));
END$$

-- ---------------------------------------------------------------------
-- 2) When a blood request's status changes to 'approved' or 'fulfilled':
--    deduct units from inventory at the linked bank (if a bank was assigned)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_after_request_update
AFTER UPDATE ON blood_requests
FOR EACH ROW
BEGIN
    IF NEW.status IN ('approved', 'fulfilled')
       AND OLD.status NOT IN ('approved', 'fulfilled')
       AND NEW.bank_id IS NOT NULL THEN

        UPDATE inventory
        SET units_available = units_available - NEW.units_needed
        WHERE bank_id = NEW.bank_id AND blood_group = NEW.blood_group;

        INSERT INTO audit_log (table_name, action, record_id, details)
        VALUES ('blood_requests', 'STATUS_CHANGE', NEW.request_id,
                CONCAT('Request #', NEW.request_id, ' -> ', NEW.status,
                       ', -', NEW.units_needed, ' unit(s) from bank #', NEW.bank_id));
    END IF;
END$$

-- ---------------------------------------------------------------------
-- 3) Audit donor record changes (insert / update / delete)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_after_donor_insert
AFTER INSERT ON donors
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, details)
    VALUES ('donors', 'INSERT', NEW.donor_id, CONCAT('New donor registered, blood group ', NEW.blood_group));
END$$

CREATE TRIGGER trg_after_donor_update
AFTER UPDATE ON donors
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, details)
    VALUES ('donors', 'UPDATE', NEW.donor_id, 'Donor record updated');
END$$

CREATE TRIGGER trg_after_donor_delete
AFTER DELETE ON donors
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, details)
    VALUES ('donors', 'DELETE', OLD.donor_id, 'Donor record deleted');
END$$

DELIMITER ;
