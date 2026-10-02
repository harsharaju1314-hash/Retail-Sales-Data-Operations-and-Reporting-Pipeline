-- ==============================================================================
-- 02_create_dim_tables.sql
-- Description: Creates Star-Schema Dimension tables in the 'edw' schema.
-- ==============================================================================

-- 1. Date Dimension (dim_date)
IF OBJECT_ID('edw.dim_date', 'U') IS NOT NULL
    DROP TABLE edw.dim_date;
GO

CREATE TABLE edw.dim_date (
    date_key INT PRIMARY KEY,              -- Format: YYYYMMDD (e.g., 20260928)
    full_date DATE NOT NULL UNIQUE,
    day_name VARCHAR(15) NOT NULL,
    day_of_week TINYINT NOT NULL,          -- 1 = Monday, 7 = Sunday
    day_of_month TINYINT NOT NULL,
    month_num TINYINT NOT NULL,
    month_name VARCHAR(15) NOT NULL,
    quarter VARCHAR(2) NOT NULL,           -- Q1, Q2, Q3, Q4
    year INT NOT NULL,
    is_weekend BIT NOT NULL                -- 1 = Weekend, 0 = Weekday
);
GO

-- 2. Region Dimension (dim_region)
IF OBJECT_ID('edw.dim_region', 'U') IS NOT NULL
    DROP TABLE edw.dim_region;
GO

CREATE TABLE edw.dim_region (
    region_id INT PRIMARY KEY,             -- Natural Key / Integer Identifier
    region_name VARCHAR(50) NOT NULL UNIQUE,
    country VARCHAR(50) NOT NULL,
    manager_name VARCHAR(100) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- 3. Store Dimension (dim_store)
IF OBJECT_ID('edw.dim_store', 'U') IS NOT NULL
    DROP TABLE edw.dim_store;
GO

CREATE TABLE edw.dim_store (
    store_key INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    store_id VARCHAR(20) NOT NULL UNIQUE,     -- Natural / Business Key (e.g. STR-101)
    store_name VARCHAR(100) NOT NULL,
    region_id INT NOT NULL,                   -- Foreign Key to dim_region
    city VARCHAR(50) NOT NULL,
    store_type VARCHAR(30) NOT NULL,          -- Flagship, Standard, Outlet
    is_active BIT NOT NULL DEFAULT 1,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_dim_store_region FOREIGN KEY (region_id) REFERENCES edw.dim_region (region_id)
);
GO

-- 4. Product Dimension (dim_product)
IF OBJECT_ID('edw.dim_product', 'U') IS NOT NULL
    DROP TABLE edw.dim_product;
GO

CREATE TABLE edw.dim_product (
    product_key INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
    product_id VARCHAR(20) NOT NULL UNIQUE,    -- Natural / Business Key (e.g. PRD-001)
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(50) NOT NULL,
    unit_cost DECIMAL(10, 2) NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Performance Indexes on Natural Keys and Join Columns
CREATE NONCLUSTERED INDEX IX_dim_store_region_id ON edw.dim_store(region_id);
CREATE NONCLUSTERED INDEX IX_dim_product_category ON edw.dim_product(category);
GO
