-- Database schema for Building Management System
-- MySQL compatible SQL with Korean support

-- Create database and use it
CREATE DATABASE IF NOT EXISTS buildings 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_general_ci;

USE buildings;

-- Enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- Create Buildings table
CREATE TABLE IF NOT EXISTS buildings (
    building_id INT AUTO_INCREMENT PRIMARY KEY,
    building_name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    building_address VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    building_floors INT NOT NULL DEFAULT 1,
    elevator INT DEFAULT 0,
    owner VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    user_id INT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_building_name (building_name),
    INDEX idx_owner (owner)
);

-- Create Floors table
CREATE TABLE IF NOT EXISTS floors (
    floor_id INT AUTO_INCREMENT PRIMARY KEY,
    floor INT NOT NULL,
    floor_space DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    building_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (building_id) REFERENCES buildings(building_id) ON DELETE CASCADE,
    INDEX idx_building_floor (building_id, floor),
    UNIQUE KEY unique_building_floor (building_id, floor)
);

-- Create Rooms table
CREATE TABLE IF NOT EXISTS rooms (
    room_id INT AUTO_INCREMENT PRIMARY KEY,
    room_number INT NOT NULL,
    room_base_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    measure_machine VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    room_name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    room_space DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    measure_no INT NOT NULL DEFAULT 0,
    strict_water DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    strict_electricity DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    measure_multiply DECIMAL(10,2) NOT NULL DEFAULT 1.00,
    floor_id INT NOT NULL,
    building_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (floor_id) REFERENCES floors(floor_id) ON DELETE CASCADE,
    FOREIGN KEY (building_id) REFERENCES buildings(building_id) ON DELETE CASCADE,
    INDEX idx_floor_room (floor_id, room_number),
    INDEX idx_building_room (building_id, room_number),
    INDEX idx_room_name (room_name)
);

-- Create Bills table
CREATE TABLE IF NOT EXISTS bills (
    bill_id INT AUTO_INCREMENT PRIMARY KEY,
    water_measure DECIMAL(10,2) DEFAULT 0.00,
    water_usage DECIMAL(10,2) DEFAULT 0.00,
    water_bill DECIMAL(10,2) DEFAULT 0.00,
    electricity_measure DECIMAL(10,2) DEFAULT 0.00,
    electricity_usage DECIMAL(10,2) DEFAULT 0.00,
    electricity_bill DECIMAL(10,2) DEFAULT 0.00,
    room_id INT NOT NULL,
    floor_id INT NOT NULL,
    building_id INT NOT NULL,
    charge_month VARCHAR(6) NOT NULL DEFAULT '', -- Format: YYYYMM
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    FOREIGN KEY (floor_id) REFERENCES floors(floor_id) ON DELETE CASCADE,
    FOREIGN KEY (building_id) REFERENCES buildings(building_id) ON DELETE CASCADE,
    INDEX idx_charge_month(charge_month),
    INDEX idx_room_bills (room_id),
    INDEX idx_floor_bills (floor_id),
    INDEX idx_building_bills (building_id),
    INDEX idx_bill_date (created_at)
);

CREATE TABLE IF NOT EXISTS bill_histories (
    bill_history_id INT AUTO_INCREMENT PRIMARY KEY,
    room_number INT NOT NULL,
    charge_month VARCHAR(6) NOT NULL DEFAULT '', -- Format: YYYYMM
    electricity_cost DECIMAL(10,2) DEFAULT 0.00,
    electricity_cost_common DECIMAL(10,2) DEFAULT 0.00,
    electricity_cost_tax DECIMAL(10,2) DEFAULT 0.00,
    electricity_cost_fund DECIMAL(10,2) DEFAULT 0.00,
    electricity_cost_total DECIMAL(10,2) DEFAULT 0.00,
    water_cost_supply DECIMAL(10,2) DEFAULT 0.00,
    water_cost_sewer DECIMAL(10,2) DEFAULT 0.00,
    water_cost_common DECIMAL(10,2) DEFAULT 0.00,
    water_cost_total DECIMAL(10,2) DEFAULT 0.00,
    total_cost DECIMAL(10,2) DEFAULT 0.00,
    building_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_building_id (building_id),
    INDEX idx_charge_month(charge_month),
    INDEX idx_room_number (room_number)
);

CREATE TABLE IF NOT EXISTS building_fees (
    building_id INT AUTO_INCREMENT PRIMARY KEY,
    general_management_fee DECIMAL(10,2) DEFAULT 0.00,
    public_inspection_fee DECIMAL(10,2) DEFAULT 0.00,
    fire_management_fee DECIMAL(10,2) DEFAULT 0.00,
    elevator_maintenance_fee DECIMAL(10,2) DEFAULT 0.00,
    septic_tank_management_fee DECIMAL(10,2) DEFAULT 0.00,
    electrical_management_fee DECIMAL(10,2) DEFAULT 0.00,
    parking_management_fee DECIMAL(10,2) DEFAULT 0.00,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'manager', 'viewer') NOT NULL DEFAULT 'viewer',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_username (username),
    INDEX idx_role (role)
);

INSERT INTO building_fees (building_id, general_management_fee, public_inspection_fee, fire_management_fee, elevator_maintenance_fee, septic_tank_management_fee, electrical_management_fee, parking_management_fee) VALUES
(1, 1834920, 1160817, 224000, 220000, 236020, 259720, 382418);




-- Insert sample data (Korean examples)
INSERT INTO users (user_id, username, password, role) VALUES
(1, 'admin', '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', 'admin');

INSERT INTO buildings (building_name, building_address, building_floors, elevator, owner, user_id) VALUES
('새아여성의원', '부산시 반여2동', 5, 1, '신창열', 1);

INSERT INTO floors (floor, floor_space, building_id) VALUES
(1, 366.29, 1),
(2, 255.98, 1),
(3, 391.74, 1),
(4, 391.74, 1),
(5, 391.74, 1);




INSERT INTO rooms (room_number, room_base_cost, measure_machine, room_name, room_space, strict_water, measure_multiply, floor_id, building_id) VALUES
(101, 332850.0,'KTF', 'KTF', 118.80, 4, 1, 1, 1),
(102, 237890.0,'약국','약국', 49.85, 1, 1, 1, 1),
(103, 150000.0,'행복마당','행복마당', 197.64, 0, 1, 1, 1),
(201, 105920.0,'천리안안과-1','천리안안과', 255.98, 0, 1, 2, 1),
(201, 105920.0,'천리안안과-2','천리안안과', 255.98, 0, 1, 2, 1),
(201, 105920.0,'천리안안과-3', '천리안안과', 255.98, 0, 1, 2, 1),
(301, 193800.0,'고려신경-1','고려신경', 391.74, 0, 25, 3, 1),
(301, 193800.0,'고려신경-2','고려신경', 391.74, 0, 25, 3, 1),
(301, 193800.0,'고려신경-3','고려신경', 391.74, 0, 25, 3, 1),
(401, 9740.0,'새아여성의원', '새아여성의원', 391.74, 0, 25, 4, 1),
(501, 169090.0,'사랑채','사랑채', 391.74, 0, 25, 5, 1);

INSERT INTO bills (water_measure, water_usage, electricity_measure, electricity_usage, charge_month, room_id, floor_id, building_id) VALUES
(0, 4, 35922.2, 722, 202506,1, 1, 1),
(0, 1, 25807, 750, 202506, 2, 1, 1),
(541, 10, 74434.3, 1986, 202506, 3, 1, 1),
(819, 3, 11753.4, 23, 202506,4, 2, 1),
(2520, 7, 99265, 2008, 202506, 5, 2, 1),
(2606, 1, 0, 0, 202506, 6, 2, 1),
(6277, 13, 4849.53, 2650, 202506, 7, 3, 1),
(6506, 30, 0, 0, 202506, 8, 3, 1),
(98, 0, 0, 0, 202506, 9, 3, 1),
(5834, 23, 3228.81, 1385, 202506, 10, 4, 1),
(12450, 123, 4139.27, 2913, 202506, 11, 5, 1),

(0, 4, 36748.2, 826, 202507, 1, 1, 1),
(0, 1, 26710, 903, 202507, 2, 1, 1),
(565, 24, 78228.3, 3794, 202507, 3, 1, 1),
(824, 5, 11700, -53, 202507, 4, 2, 1),
(2527, 7, 101856.5, 2594, 202507, 5, 2, 1),
(2607, 1, 0, 0, 202507, 6, 2, 1),
(6299, 22, 4997.14, 3691, 202507, 7, 3, 1),
(6551, 45, 0, 0, 202507, 8, 3, 1),
(98, 0, 0, 0, 202507, 9, 3, 1),
(5860, 26, 3316.35, 2189, 202507, 10, 4, 1),
(12584, 134, 4286.51, 3681, 202507, 11, 5, 1);