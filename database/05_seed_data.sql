-- =====================================================================
-- LifeDrop BD - Seed Data
-- Blood compatibility rules + sample blood banks, admin user, inventory
-- =====================================================================
USE lifedrop_bd;

-- ---------------------------------------------------------------------
-- Blood compatibility (standard medical rules)
-- O- is the universal donor, AB+ is the universal recipient
-- ---------------------------------------------------------------------
INSERT INTO blood_compatibility (donor_group, recipient_group) VALUES
('O-','O-'),('O-','O+'),('O-','A-'),('O-','A+'),('O-','B-'),('O-','B+'),('O-','AB-'),('O-','AB+'),
('O+','O+'),('O+','A+'),('O+','B+'),('O+','AB+'),
('A-','A-'),('A-','A+'),('A-','AB-'),('A-','AB+'),
('A+','A+'),('A+','AB+'),
('B-','B-'),('B-','B+'),('B-','AB-'),('B-','AB+'),
('B+','B+'),('B+','AB+'),
('AB-','AB-'),('AB-','AB+'),
('AB+','AB+');

-- ---------------------------------------------------------------------
-- Sample blood banks (Dhaka)
-- ---------------------------------------------------------------------
INSERT INTO blood_banks (name, area, district, contact) VALUES
('Dhaka Central Blood Bank', 'Dhanmondi', 'Dhaka', '01700000001'),
('Sandhani Blood Bank', 'Shahbagh', 'Dhaka', '01700000002'),
('Mirpur Community Blood Bank', 'Mirpur', 'Dhaka', '01700000003'),
('Gulshan Blood Center', 'Gulshan', 'Dhaka', '01700000004');

-- ---------------------------------------------------------------------
-- Initial inventory (some starting stock so Search/Insights pages aren't empty)
-- ---------------------------------------------------------------------
INSERT INTO inventory (bank_id, blood_group, units_available) VALUES
(1, 'A+', 12), (1, 'O+', 20), (1, 'B+', 8), (1, 'O-', 5),
(2, 'AB+', 4), (2, 'A-', 6), (2, 'O+', 15), (2, 'B-', 3),
(3, 'O+', 10), (3, 'A+', 7), (3, 'B+', 9),
(4, 'AB-', 2), (4, 'O-', 6), (4, 'A+', 5);

-- ---------------------------------------------------------------------
-- Default admin login
-- email: admin@lifedrop.bd  |  password: Admin@123
-- (password_hash below is generated with Werkzeug's generate_password_hash,
--  the same function app.py uses to check logins. Change this password
--  after first login in a real deployment.)
-- ---------------------------------------------------------------------
INSERT INTO users (name, email, password_hash, phone, role) VALUES
('System Admin', 'admin@lifedrop.bd', 'scrypt:32768:8:1$wjbozzqa7T1pcr1s$eb0ee1b70c04447563138dd64c39cfa5cbde5fb00ad378f1ff38120bdc5eb23c95edfb3df0c3f9b96541f8855d7ebfff44cfcea08aad9228ff72914b6e08b740', '01700000000', 'admin');
