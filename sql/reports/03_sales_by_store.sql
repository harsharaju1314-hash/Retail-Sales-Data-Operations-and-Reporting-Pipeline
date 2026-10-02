-- ==============================================================================
-- Report 03: Sales by Store
-- Business Purpose: Compares retail performance across individual store locations
-- and store formats (Flagship vs Standard vs Outlet).
-- ==============================================================================

SELECT 
    s.store_id,
    s.store_name,
    s.city,
    s.store_type,
    r.region_name,
    COUNT(f.sales_key) AS total_transactions,
    SUM(f.quantity) AS total_units_sold,
    SUM(CASE WHEN f.transaction_status = 'Completed' THEN f.net_amount ELSE 0 END) AS net_sales_revenue,
    ROUND(
        AVG(CASE WHEN f.transaction_status = 'Completed' THEN f.net_amount END), 
        2
    ) AS avg_transaction_value
FROM edw.fact_sales f
INNER JOIN edw.dim_store s ON f.store_key = s.store_key
INNER JOIN edw.dim_region r ON s.region_id = r.region_id
GROUP BY 
    s.store_id,
    s.store_name,
    s.city,
    s.store_type,
    r.region_name
HAVING 
    COUNT(f.sales_key) > 0
ORDER BY 
    net_sales_revenue DESC;
