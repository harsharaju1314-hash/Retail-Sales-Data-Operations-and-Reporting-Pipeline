-- ==============================================================================
-- 01_create_schemas_and_staging.sql
-- Description: Creates schemas (stg, edw, ops), logging table, and staging tables.
-- Target DB: Azure SQL Database / Microsoft SQL Server
-- ==============================================================================

-- 1. Create Dedicated Schemas
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
    EXEC('CREATE SCHEMA stg;');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'edw')
    EXEC('CREATE SCHEMA edw;');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ops')
    EXEC('CREATE SCHEMA ops;');
GO

-- 2. Create Pipeline Operations Logging Table
IF OBJECT_ID('ops.pipeline_execution_logs', 'U') IS NOT NULL
    DROP TABLE ops.pipeline_execution_logs;
GO

CREATE TABLE ops.pipeline_execution_logs (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    pipeline_name VARCHAR(100) NOT NULL,
    run_id VARCHAR(100) NOT NULL,
    trigger_date DATE NOT NULL,
    step_name VARCHAR(100) NOT NULL,
    rows_inserted INT DEFAULT 0,
    rows_updated INT DEFAULT 0,
    rows_rejected INT DEFAULT 0,
    status VARCHAR(20) NOT NULL, -- 'SUCCESS', 'FAILED', 'IN_PROGRESS'
    error_message NVARCHAR(MAX) NULL,
    start_time DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    end_time DATETIME2 NULL,
    execution_duration_sec INT NULL
);
GO

-- 3. Create Staging Table for Daily Sales Transactions
IF OBJECT_ID('stg.daily_sales_transactions', 'U') IS NOT NULL
    DROP TABLE stg.daily_sales_transactions;
GO

CREATE TABLE stg.daily_sales_transactions (
    transaction_id VARCHAR(50) NOT NULL,
    transaction_date DATE NOT NULL,
    store_id VARCHAR(20) NOT NULL,
    store_name VARCHAR(100) NOT NULL,
    region VARCHAR(50) NOT NULL,
    product_id VARCHAR(20) NOT NULL,
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    discount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    gross_amount DECIMAL(10, 2) NOT NULL,
    net_amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    transaction_status VARCHAR(30) NOT NULL,
    processed_timestamp DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Create an index on staging transaction_id and transaction_date for fast lookups/merge
CREATE NONCLUSTERED INDEX IX_stg_sales_txnid_date 
ON stg.daily_sales_transactions (transaction_id, transaction_date);
GO
