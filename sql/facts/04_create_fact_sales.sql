-- ==============================================================================
-- 04_create_fact_sales.sql
-- Description: Creates the central Fact table (fact_sales) in the 'edw' schema.
-- ==============================================================================

IF OBJECT_ID('edw.fact_sales', 'U') IS NOT NULL
    DROP TABLE edw.fact_sales;
GO

CREATE TABLE edw.fact_sales (
    sales_key BIGINT IDENTITY(1,1) PRIMARY KEY,      -- Surrogate Primary Key
    transaction_id VARCHAR(50) NOT NULL,             -- Degenerate Dimension (Business Identifier)
    date_key INT NOT NULL,                           -- Foreign Key -> edw.dim_date
    store_key INT NOT NULL,                          -- Foreign Key -> edw.dim_store
    product_key INT NOT NULL,                        -- Foreign Key -> edw.dim_product
    region_id INT NOT NULL,                          -- Foreign Key -> edw.dim_region
    quantity INT NOT NULL,                           -- Measure: Quantity Sold
    unit_price DECIMAL(10, 2) NOT NULL,              -- Measure: Unit Selling Price
    discount_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00, -- Measure: Discount Applied
    gross_amount DECIMAL(10, 2) NOT NULL,            -- Measure: (quantity * unit_price)
    net_amount DECIMAL(10, 2) NOT NULL,              -- Measure: (gross_amount - discount_amount)
    payment_method VARCHAR(30) NOT NULL,             -- Dimensional Attribute
    transaction_status VARCHAR(30) NOT NULL,         -- Dimensional Attribute ('Completed', 'Cancelled', etc.)
    created_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    -- Foreign Key Constraints
    CONSTRAINT FK_fact_sales_dim_date FOREIGN KEY (date_key) REFERENCES edw.dim_date (date_key),
    CONSTRAINT FK_fact_sales_dim_store FOREIGN KEY (store_key) REFERENCES edw.dim_store (store_key),
    CONSTRAINT FK_fact_sales_dim_product FOREIGN KEY (product_key) REFERENCES edw.dim_product (product_key),
    CONSTRAINT FK_fact_sales_dim_region FOREIGN KEY (region_id) REFERENCES edw.dim_region (region_id)
);
GO

-- Indexes on Foreign Keys and Dimensions to optimize Analytical BI queries
CREATE NONCLUSTERED INDEX IX_fact_sales_date_key ON edw.fact_sales(date_key);
CREATE NONCLUSTERED INDEX IX_fact_sales_store_key ON edw.fact_sales(store_key);
CREATE NONCLUSTERED INDEX IX_fact_sales_product_key ON edw.fact_sales(product_key);
CREATE NONCLUSTERED INDEX IX_fact_sales_region_id ON edw.fact_sales(region_id);
CREATE NONCLUSTERED INDEX IX_fact_sales_status ON edw.fact_sales(transaction_status);
CREATE UNIQUE NONCLUSTERED INDEX UX_fact_sales_transaction_id ON edw.fact_sales(transaction_id);
GO
