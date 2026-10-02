-- ==============================================================================
-- Report 04: Sales by Product Category & Margin Analysis
-- Business Purpose: Analyzes revenue generation, discount depth, and estimated 
-- gross profit margin across categories and subcategories.
-- ==============================================================================

SELECT 
    p.category,
    p.subcategory,
    COUNT(f.sales_key) AS total_orders,
    SUM(f.quantity) AS units_sold,
    SUM(f.gross_amount) AS total_gross_sales,
    SUM(f.discount_amount) AS total_discounts,
    SUM(f.net_amount) AS total_net_sales,
    -- Effective discount rate
    ROUND(100.0 * SUM(f.discount_amount) / NULLIF(SUM(f.gross_amount), 0), 2) AS effective_discount_pct,
    -- Estimated Gross Profit = Net Sales - Total Cost of Goods Sold (COGS)
    SUM(f.net_amount) - SUM(f.quantity * p.unit_cost) AS estimated_gross_profit,
    -- Estimated Gross Margin %
    ROUND(
        100.0 * (SUM(f.net_amount) - SUM(f.quantity * p.unit_cost)) / NULLIF(SUM(f.net_amount), 0), 
        2
    ) AS estimated_margin_pct
FROM edw.fact_sales f
INNER JOIN edw.dim_product p ON f.product_key = p.product_key
WHERE f.transaction_status = 'Completed'
GROUP BY 
    p.category,
    p.subcategory
ORDER BY 
    total_net_sales DESC;
