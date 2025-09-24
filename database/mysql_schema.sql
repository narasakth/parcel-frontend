-- ParcelFlow Database Schema
-- MySQL 8.0+ Compatible

-- Create Database
CREATE DATABASE IF NOT EXISTS parcelflow_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE parcelflow_db;

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    company VARCHAR(255),
    role ENUM('admin', 'manager', 'user') DEFAULT 'user',
    email_verified_at TIMESTAMP NULL,
    remember_token VARCHAR(100) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_email (email),
    INDEX idx_created_at (created_at)
);

-- Parcels Table
CREATE TABLE IF NOT EXISTS parcels (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tracking_no VARCHAR(50) NOT NULL UNIQUE,
    user_id BIGINT UNSIGNED NOT NULL,
    
    -- Sender Information
    sender_name VARCHAR(255) NOT NULL,
    sender_phone VARCHAR(20) NOT NULL,
    sender_email VARCHAR(255),
    sender_address TEXT NOT NULL,
    
    -- Receiver Information
    receiver_name VARCHAR(255) NOT NULL,
    receiver_phone VARCHAR(20) NOT NULL,
    receiver_email VARCHAR(255),
    receiver_address TEXT NOT NULL,
    
    -- Package Information
    package_type ENUM('document', 'package', 'fragile', 'electronics', 'clothing', 'other') DEFAULT 'package',
    package_weight DECIMAL(8,2), -- in kg
    package_dimensions VARCHAR(50), -- LxWxH in cm
    package_description TEXT,
    package_value DECIMAL(10,2), -- declared value
    
    -- Delivery Information
    status ENUM('CREATED', 'IN_HUB', 'OUT_FOR_DELIVERY', 'DELIVERED', 'DELAYED', 'CANCELED') DEFAULT 'CREATED',
    shipping_fee DECIMAL(10,2) NOT NULL,
    delivery_date DATE,
    estimated_delivery TIMESTAMP NULL,
    actual_delivery TIMESTAMP NULL,
    
    -- Additional Information
    notes TEXT,
    special_instructions TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_tracking_no (tracking_no),
    INDEX idx_status (status),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at)
);

-- Parcel Status History Table
CREATE TABLE IF NOT EXISTS parcel_status_history (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    parcel_id BIGINT UNSIGNED NOT NULL,
    status ENUM('CREATED', 'IN_HUB', 'OUT_FOR_DELIVERY', 'DELIVERED', 'DELAYED', 'CANCELED') NOT NULL,
    location VARCHAR(255),
    description TEXT,
    updated_by BIGINT UNSIGNED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (parcel_id) REFERENCES parcels(id) ON DELETE CASCADE,
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_parcel_id (parcel_id),
    INDEX idx_created_at (created_at)
);

-- Revenue Table
CREATE TABLE IF NOT EXISTS revenue (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    parcel_id BIGINT UNSIGNED NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'THB',
    period DATE NOT NULL, -- daily, weekly, monthly
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (parcel_id) REFERENCES parcels(id) ON DELETE CASCADE,
    INDEX idx_period (period),
    INDEX idx_created_at (created_at)
);

-- Delivery Routes Table
CREATE TABLE IF NOT EXISTS delivery_routes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    route_name VARCHAR(255) NOT NULL,
    from_location VARCHAR(255) NOT NULL,
    to_location VARCHAR(255) NOT NULL,
    estimated_time INT, -- in hours
    base_price DECIMAL(10,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_is_active (is_active)
);

-- Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    parcel_id BIGINT UNSIGNED,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('info', 'warning', 'success', 'error') DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parcel_id) REFERENCES parcels(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at)
);

-- System Settings Table
CREATE TABLE IF NOT EXISTS system_settings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert Default Admin User
INSERT INTO users (first_name, last_name, email, password_hash, role) 
VALUES ('Admin', 'User', 'admin@parcelflow.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin')
ON DUPLICATE KEY UPDATE email = email;

-- Insert Default System Settings
INSERT INTO system_settings (setting_key, setting_value, description) VALUES
('company_name', 'ParcelFlow', 'Company name'),
('company_email', 'info@parcelflow.com', 'Company email'),
('company_phone', '+1-555-PARCEL', 'Company phone'),
('default_currency', 'THB', 'Default currency'),
('max_package_weight', '50', 'Maximum package weight in kg'),
('delivery_timeout', '72', 'Delivery timeout in hours')
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value);

-- Insert Sample Delivery Routes
INSERT INTO delivery_routes (route_name, from_location, to_location, estimated_time, base_price) VALUES
('Bangkok-Central', 'Bangkok', 'Central Region', 24, 150.00),
('Bangkok-North', 'Bangkok', 'Northern Region', 48, 200.00),
('Bangkok-South', 'Bangkok', 'Southern Region', 36, 180.00),
('Bangkok-East', 'Bangkok', 'Eastern Region', 12, 100.00),
('Local-Delivery', 'Local Area', 'Same City', 6, 50.00)
ON DUPLICATE KEY UPDATE base_price = VALUES(base_price);

-- Create Views for Better Performance

-- Revenue Summary View
CREATE OR REPLACE VIEW revenue_summary AS
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_parcels,
    SUM(amount) as total_revenue,
    AVG(amount) as average_revenue
FROM revenue 
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Parcel Status Summary View
CREATE OR REPLACE VIEW parcel_status_summary AS
SELECT 
    status,
    COUNT(*) as count,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM parcels)), 2) as percentage
FROM parcels 
GROUP BY status;

-- Recent Parcels View
CREATE OR REPLACE VIEW recent_parcels AS
SELECT 
    p.id,
    p.tracking_no,
    p.sender_name,
    p.receiver_name,
    p.status,
    p.shipping_fee,
    p.created_at,
    u.first_name,
    u.last_name,
    u.email
FROM parcels p
JOIN users u ON p.user_id = u.id
ORDER BY p.created_at DESC
LIMIT 100;

-- Create Stored Procedures

-- Procedure to update parcel status
DELIMITER //
CREATE PROCEDURE UpdateParcelStatus(
    IN p_parcel_id BIGINT,
    IN p_status VARCHAR(50),
    IN p_location VARCHAR(255),
    IN p_description TEXT,
    IN p_updated_by BIGINT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    -- Update parcel status
    UPDATE parcels 
    SET status = p_status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_parcel_id;
    
    -- Insert status history
    INSERT INTO parcel_status_history (parcel_id, status, location, description, updated_by)
    VALUES (p_parcel_id, p_status, p_location, p_description, p_updated_by);
    
    -- Create notification
    INSERT INTO notifications (user_id, parcel_id, title, message, type)
    SELECT 
        user_id,
        p_parcel_id,
        CONCAT('Parcel Status Updated: ', p_status),
        COALESCE(p_description, CONCAT('Your parcel status has been updated to: ', p_status)),
        CASE 
            WHEN p_status = 'DELIVERED' THEN 'success'
            WHEN p_status = 'DELAYED' THEN 'warning'
            ELSE 'info'
        END
    FROM parcels WHERE id = p_parcel_id;
    
    COMMIT;
END //
DELIMITER ;

-- Procedure to generate tracking number
DELIMITER //
CREATE FUNCTION GenerateTrackingNumber() RETURNS VARCHAR(50)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE tracking_no VARCHAR(50);
    DECLARE counter INT DEFAULT 1;
    
    REPEAT
        SET tracking_no = CONCAT('PF', DATE_FORMAT(NOW(), '%Y%m%d'), LPAD(counter, 4, '0'));
        SET counter = counter + 1;
    UNTIL NOT EXISTS (SELECT 1 FROM parcels WHERE parcels.tracking_no = tracking_no) END REPEAT;
    
    RETURN tracking_no;
END //
DELIMITER ;

-- Create Indexes for Better Performance
CREATE INDEX idx_parcels_status_created ON parcels(status, created_at);
CREATE INDEX idx_parcels_user_status ON parcels(user_id, status);
CREATE INDEX idx_revenue_period_amount ON revenue(period, amount);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read, created_at);

-- Grant Permissions (adjust as needed for your setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON parcelflow_db.* TO 'parcelflow_user'@'%';
-- FLUSH PRIVILEGES;

-- Sample Data (Optional - for testing)
INSERT INTO parcels (
    tracking_no, user_id, sender_name, sender_phone, sender_address,
    receiver_name, receiver_phone, receiver_address, status, shipping_fee
) VALUES
('PF20241201001', 1, 'John Doe', '+1234567890', '123 Main St, Bangkok',
 'Jane Smith', '+0987654321', '456 Oak Ave, Chiang Mai', 'OUT_FOR_DELIVERY', 150.00),
('PF20241201002', 1, 'Alice Johnson', '+1122334455', '789 Pine St, Bangkok',
 'Bob Wilson', '+5566778899', '321 Elm St, Phuket', 'DELIVERED', 200.00);

COMMIT;
