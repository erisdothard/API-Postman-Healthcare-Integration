-- Healthcare Integration Portfolio - Seed Data
-- Run after schema.sql

-- Provider reference data for mid-flight NPI lookup
INSERT INTO providers (npi, first_name, last_name, specialty, department) VALUES
('1234567890', 'Sarah', 'Chen', 'Internal Medicine', 'Medicine'),
('0987654321', 'James', 'Wilson', 'Pathology', 'Laboratory'),
('1122334455', 'Maria', 'Garcia', 'Emergency Medicine', 'Emergency');
