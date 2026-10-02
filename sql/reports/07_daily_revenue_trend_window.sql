-- ==============================================================================
-- Report 07: Daily Revenue Trend, Moving Averages & Cumulative Revenue
-- Business Purpose: Analyzes revenue trajectory over time using Window Functions
-- (3-day moving average, cumulative running revenue total, day-over-day growth).
-- ==============================================================================

WITH DailyCompletedSales AS (
    SELECT 
        d.full_date,
        d.day_name,
        COUNT(f.sales_key) AS completed_orders,
        SUM(f.quantity) AS units_sold,
        SUM(f.net_amount) AS daily_net_revenue
    FROM edw.fact_sales f
    INNER JOIN edw.dim_date d ON f.date_key = d.date_key
    WHERE f.transaction_status = 'Completed'
    GROUP BY 
        d.full_date,
        d.day_name
)
SELECT 
    full_date,
    day_name,
    completed_orders,
    units_sold,
    daily_net_revenue,
    -- 3-Day Moving Average Net Revenue
    ROUND(
        AVG(daily_net_revenue) OVER (
            ORDER BY full_date 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 
        2
    ) AS moving_avg_3d_revenue,
    -- Cumulative Running Total Net Revenue
    SUM(daily_net_revenue) OVER (
        ORDER BY full_date 
        ROWS UNBOUNDED PRECEDING
    ) AS running_total_revenue,
    -- Day-Over-Day Revenue Change %
    ROUND(
        100.0 * (daily_net_revenue - LAG(daily_net_revenue, 1) OVER (ORDER BY full_date)) / 
        NULLIF(LAG(daily_net_revenue, 1) OVER (ORDER BY full_date), 0),
        2
    ) AS dod_growth_pct
FROM DailyCompletedSales
ORDER BY 
    full_date ASC;
