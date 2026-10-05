-- =====================================================================
-- LifeDrop BD - Stored Procedures
-- =====================================================================
USE lifedrop_bd;

DELIMITER $$

-- ---------------------------------------------------------------------
-- sp_find_compatible_donors
-- Finds eligible donors (>=90 days since last donation, or never donated)
-- whose blood group is compatible with the requested recipient group,
-- optionally filtered by area.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_find_compatible_donors (
    IN p_recipient_group VARCHAR(3),
    IN p_area VARCHAR(80)
)
BEGIN
    SELECT u.name, u.phone, d.blood_group, d.area, d.district,
           d.last_donation_date, d.total_donations
    FROM donors d
    JOIN users u ON u.user_id = d.donor_id
    JOIN blood_compatibility bc ON bc.donor_group = d.blood_group
    WHERE bc.recipient_group = p_recipient_group
      AND (p_area IS NULL OR p_area = '' OR d.area = p_area)
      AND (d.last_donation_date IS NULL OR DATEDIFF(CURDATE(), d.last_donation_date) >= 90)
    ORDER BY d.last_donation_date IS NULL DESC, d.last_donation_date ASC;
END$$

-- ---------------------------------------------------------------------
-- sp_approve_request
-- Approves a blood request only if the linked bank has enough stock.
-- Wrapped in a transaction: inventory deduction and status update
-- either both succeed or both roll back (data stays consistent).
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_approve_request (
    IN p_request_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_bank_id INT;
    DECLARE v_group VARCHAR(3);
    DECLARE v_units INT;
    DECLARE v_available INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Error: transaction rolled back';
    END;

    START TRANSACTION;

    SELECT bank_id, blood_group, units_needed
    INTO v_bank_id, v_group, v_units
    FROM blood_requests WHERE request_id = p_request_id
    FOR UPDATE;

    IF v_bank_id IS NULL THEN
        SET p_message = 'Error: no blood bank assigned to this request yet';
        ROLLBACK;
    ELSE
        SELECT units_available INTO v_available
        FROM inventory
        WHERE bank_id = v_bank_id AND blood_group = v_group
        FOR UPDATE;

        IF v_available IS NULL OR v_available < v_units THEN
            SET p_message = 'Error: not enough stock at the selected bank';
            ROLLBACK;
        ELSE
            UPDATE blood_requests
            SET status = 'approved', resolved_at = NOW()
            WHERE request_id = p_request_id;
            -- inventory deduction happens automatically via trg_after_request_update
            COMMIT;
            SET p_message = 'Request approved successfully';
        END IF;
    END IF;
END$$

DELIMITER ;
