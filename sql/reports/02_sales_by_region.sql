-- ==============================================================================
-- Report 02: Sales by Region
-- Business Purpose: Evaluates regional sales performance, regional manager 
-- accountability, and calculates the percentage contribution of each region 
-- to total global net revenue using CTE and Window Functions.
-- ==============================================================================

WITH RegionalAggregates AS (
    SELECT 
        r.region_id,
        r.region_name,
        r.country,
        r.manager_name,
        COUNT(f.sales_key) AS total_orders,
        SUM(f.quantity) AS total_units_sold,
        SUM(CASE WHEN f.transaction_status = 'Completed' THEN f.net_amount ELSE 0 END) AS completed_net_revenue
    FROM edw.fact_sales f
    INNER JOIN edw.dim_region r ON f.region_id = r.region_id
    GROUP BY 
        r.region_id,
        r.region_name,
        r.country,
        r.manager_name
)
SELECT 
    region_name,
    country,
    manager_name,
    total_orders,
    total_units_sold,
    completed_net_revenue,
    -- Percentage contribution to total global revenue
    ROUND(
        100.0 * completed_net_revenue / NULLIF(SUM(completed_net_revenue) OVER(), 0), 
        2
    ) AS pct_of_global_revenue,
    DENSE_RANK() OVER (ORDER BY completed_net_revenue DESC) AS revenue_rank
FROM RegionalAggregates
ORDER BY 
    completed_net_revenue DESC;
