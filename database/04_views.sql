-- =====================================================================
-- LifeDrop BD - Views
-- =====================================================================
USE lifedrop_bd;

-- Current stock at every blood bank, human-readable
CREATE OR REPLACE VIEW view_available_inventory AS
SELECT b.name AS bank_name, b.area, b.district,
       i.blood_group, i.units_available, i.updated_at
FROM inventory i
JOIN blood_banks b ON b.bank_id = i.bank_id
ORDER BY b.name, i.blood_group;

-- Donors currently eligible to donate (never donated, or >=90 days ago)
CREATE OR REPLACE VIEW view_active_donors AS
SELECT u.user_id AS donor_id, u.name, u.phone, d.blood_group, d.area, d.district,
       d.last_donation_date, d.total_donations,
       CASE
           WHEN d.last_donation_date IS NULL THEN 'Never donated - eligible'
           WHEN DATEDIFF(CURDATE(), d.last_donation_date) >= 90 THEN 'Eligible'
           ELSE CONCAT('Eligible in ', 90 - DATEDIFF(CURDATE(), d.last_donation_date), ' day(s)')
       END AS eligibility_status
FROM donors d
JOIN users u ON u.user_id = d.donor_id;

-- Monthly donation counts, most recent first
CREATE OR REPLACE VIEW view_monthly_donations AS
SELECT DATE_FORMAT(donation_date, '%Y-%m') AS month,
       COUNT(*) AS total_donations,
       SUM(units) AS total_units
FROM donations
GROUP BY DATE_FORMAT(donation_date, '%Y-%m')
ORDER BY month DESC;

-- Request summary per blood group (demand vs how much got fulfilled)
CREATE OR REPLACE VIEW view_request_summary AS
SELECT blood_group,
       COUNT(*) AS total_requests,
       SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending,
       SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved,
       SUM(CASE WHEN status = 'fulfilled' THEN 1 ELSE 0 END) AS fulfilled,
       SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS rejected,
       SUM(CASE WHEN urgency = 'emergency' THEN 1 ELSE 0 END) AS emergency_count
FROM blood_requests
GROUP BY blood_group;
