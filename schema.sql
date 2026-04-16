-- Healthcare Integration Portfolio - Database Schema
-- PostgreSQL 

-- Lab Results table (exists in both bridgelink_db and mirthdb)
CREATE TABLE lab_results (
    id SERIAL PRIMARY KEY,
    patient_id VARCHAR(50),
    patient_name VARCHAR(100),
    test_name VARCHAR(100),
    result_value VARCHAR(50),
    result_status VARCHAR(20),
    abnormal_flag VARCHAR(10),
    units VARCHAR(20),
    ordering_provider VARCHAR(100),
    provider_specialty VARCHAR(100),
    admission_status VARCHAR(20),
    received_at TIMESTAMP DEFAULT NOW()
);

-- Patients table (populated by ADT_Processing channel)
CREATE TABLE patients (
    id SERIAL PRIMARY KEY,
    patient_id VARCHAR(50) UNIQUE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    dob DATE,
    gender VARCHAR(10),
    admission_status VARCHAR(20),
    attending_physician VARCHAR(100),
    admit_date TIMESTAMP,
    discharge_date TIMESTAMP,
    last_updated TIMESTAMP DEFAULT NOW()
);

-- Providers reference table (lookup data for mid-flight enrichment)
CREATE TABLE providers (
    npi VARCHAR(10) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    specialty VARCHAR(100),
    department VARCHAR(100)
);
