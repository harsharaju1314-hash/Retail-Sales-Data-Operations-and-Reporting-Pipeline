-- ==============================================================================
-- Report 05: Top-Selling Products
-- Business Purpose: Identifies top products by net sales revenue and volume 
-- using Window Functions (DENSE_RANK) to support inventory & merchandising decisions.
-- ==============================================================================

WITH ProductSalesSummary AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        p.base_price,
        COUNT(f.sales_key) AS total_orders,
        SUM(f.quantity) AS total_units_sold,
        SUM(f.net_amount) AS total_net_revenue
    FROM edw.fact_sales f
    INNER JOIN edw.dim_product p ON f.product_key = p.product_key
    WHERE f.transaction_status = 'Completed'
    GROUP BY 
        p.product_id,
        p.product_name,
        p.category,
        p.base_price
)
SELECT 
    DENSE_RANK() OVER (ORDER BY total_net_revenue DESC) AS revenue_rank,
    product_id,
    product_name,
    category,
    base_price,
    total_orders,
    total_units_sold,
    total_net_revenue,
    DENSE_RANK() OVER (ORDER BY total_units_sold DESC) AS volume_rank
FROM ProductSalesSummary
ORDER BY 
    revenue_rank ASC;
