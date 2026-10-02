-- ==============================================================================
-- 03_populate_dimensions.sql
-- Description: Seeds dimension tables with synthetic master data.
-- ==============================================================================

-- 1. Populate dim_region
MERGE INTO edw.dim_region AS target
USING (
    VALUES 
        (1, 'North America - East', 'United States', 'Sarah Jenkins'),
        (2, 'North America - West', 'United States', 'David Martinez'),
        (3, 'Europe - Central', 'Germany', 'Hans Schmidt'),
        (4, 'Europe - West', 'United Kingdom', 'Emma Watson'),
        (5, 'Asia Pacific', 'Singapore', 'Wei Chen')
) AS source (region_id, region_name, country, manager_name)
ON target.region_id = source.region_id
WHEN MATCHED THEN
    UPDATE SET 
        region_name = source.region_name,
        country = source.country,
        manager_name = source.manager_name
WHEN NOT MATCHED THEN
    INSERT (region_id, region_name, country, manager_name)
    VALUES (source.region_id, source.region_name, source.country, source.manager_name);
GO

-- 2. Populate dim_store
MERGE INTO edw.dim_store AS target
USING (
    VALUES
        ('STR-101', 'Downtown Manhattan Flagship', 1, 'New York', 'Flagship'),
        ('STR-102', 'Boston Back Bay Store', 1, 'Boston', 'Standard'),
        ('STR-103', 'Seattle Downtown Outlet', 2, 'Seattle', 'Outlet'),
        ('STR-104', 'San Francisco Union Sq', 2, 'San Francisco', 'Flagship'),
        ('STR-105', 'Berlin Alexanderplatz', 3, 'Berlin', 'Standard'),
        ('STR-106', 'Munich City Center', 3, 'Munich', 'Standard'),
        ('STR-107', 'London Oxford Street', 4, 'London', 'Flagship'),
        ('STR-108', 'Manchester Arndale', 4, 'Manchester', 'Standard'),
        ('STR-109', 'Singapore Marina Mall', 5, 'Singapore', 'Flagship'),
        ('STR-110', 'Sydney George St Store', 5, 'Sydney', 'Standard')
) AS source (store_id, store_name, region_id, city, store_type)
ON target.store_id = source.store_id
WHEN MATCHED THEN
    UPDATE SET
        store_name = source.store_name,
        region_id = source.region_id,
        city = source.city,
        store_type = source.store_type
WHEN NOT MATCHED THEN
    INSERT (store_id, store_name, region_id, city, store_type)
    VALUES (source.store_id, source.store_name, source.region_id, source.city, source.store_type);
GO

-- 3. Populate dim_product
MERGE INTO edw.dim_product AS target
USING (
    VALUES
        ('PRD-001', 'Ultra Wireless Noise-Cancelling Headphones', 'Electronics', 'Audio', 85.00, 149.99),
        ('PRD-002', 'Smart Fitness Tracker Band 5', 'Electronics', 'Wearables', 28.00, 59.99),
        ('PRD-003', '4K Ultra-HD Action Camera Pro', 'Electronics', 'Cameras', 120.00, 229.99),
        ('PRD-004', 'Ergonomic Mesh Office Chair', 'Home & Office', 'Furniture', 95.00, 189.99),
        ('PRD-005', 'Stainless Steel Thermal Coffee Tumbler 20oz', 'Home & Office', 'Drinkware', 8.50, 24.99),
        ('PRD-006', 'Organic Cotton Crewneck T-Shirt', 'Apparel', 'Men''s Clothing', 7.00, 19.99),
        ('PRD-007', 'Water-Resistant Trail Hiking Jacket', 'Apparel', 'Outerwear', 45.00, 99.99),
        ('PRD-008', 'Breathable Athletic Running Shoes', 'Footwear', 'Sports Footwear', 38.00, 89.99),
        ('PRD-009', 'Compact Mechanical Gaming Keyboard', 'Electronics', 'Computer Accessories', 42.00, 79.99),
        ('PRD-010', 'Eco-Friendly Yoga Mat 6mm', 'Sports & Fitness', 'Fitness Accessories', 12.00, 29.99)
) AS source (product_id, product_name, category, subcategory, unit_cost, base_price)
ON target.product_id = source.product_id
WHEN MATCHED THEN
    UPDATE SET
        product_name = source.product_name,
        category = source.category,
        subcategory = source.subcategory,
        unit_cost = source.unit_cost,
        base_price = source.base_price
WHEN NOT MATCHED THEN
    INSERT (product_id, product_name, category, subcategory, unit_cost, base_price)
    VALUES (source.product_id, source.product_name, source.category, source.subcategory, source.unit_cost, source.base_price);
GO

-- 4. Populate dim_date (Generate a range of dates: 2026-01-01 to 2026-12-31)
SET NOCOUNT ON;
DECLARE @StartDate DATE = '2026-01-01';
DECLARE @EndDate DATE = '2026-12-31';

WHILE @StartDate <= @EndDate
BEGIN
    DECLARE @DateKey INT = YEAR(@StartDate) * 10000 + MONTH(@StartDate) * 100 + DAY(@StartDate);
    
    IF NOT EXISTS (SELECT 1 FROM edw.dim_date WHERE date_key = @DateKey)
    BEGIN
        INSERT INTO edw.dim_date (
            date_key,
            full_date,
            day_name,
            day_of_week,
            day_of_month,
            month_num,
            month_name,
            quarter,
            year,
            is_weekend
        )
        VALUES (
            @DateKey,
            @StartDate,
            DATENAME(WEEKDAY, @StartDate),
            DATEPART(WEEKDAY, @StartDate),
            DAY(@StartDate),
            MONTH(@StartDate),
            DATENAME(MONTH, @StartDate),
            'Q' + CAST(DATEPART(QUARTER, @StartDate) AS VARCHAR(1)),
            YEAR(@StartDate),
            CASE WHEN DATEPART(WEEKDAY, @StartDate) IN (1, 7) THEN 1 ELSE 0 END
        );
    END;

    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;
GO
