-- ==============================================================================
-- Report 01: Daily Sales Summary
-- Business Purpose: Provides an executive daily summary of total transactions,
-- gross sales, discounts given, net revenue, and average transaction value (AOV).
-- ==============================================================================

SELECT 
    d.full_date AS report_date,
    d.day_name,
    COUNT(f.sales_key) AS total_transactions,
    SUM(CASE WHEN f.transaction_status = 'Completed' THEN 1 ELSE 0 END) AS completed_transactions,
    SUM(f.quantity) AS total_units_sold,
    SUM(f.gross_amount) AS total_gross_revenue,
    SUM(f.discount_amount) AS total_discounts_granted,
    SUM(f.net_amount) AS total_net_revenue,
    -- Average Order Value (AOV) for completed transactions
    ROUND(
        SUM(CASE WHEN f.transaction_status = 'Completed' THEN f.net_amount ELSE 0 END) / 
        NULLIF(SUM(CASE WHEN f.transaction_status = 'Completed' THEN 1 ELSE 0 END), 0), 
        2
    ) AS avg_completed_order_value
FROM edw.fact_sales f
INNER JOIN edw.dim_date d ON f.date_key = d.date_key
GROUP BY 
    d.full_date, 
    d.day_name
ORDER BY 
    d.full_date DESC;
