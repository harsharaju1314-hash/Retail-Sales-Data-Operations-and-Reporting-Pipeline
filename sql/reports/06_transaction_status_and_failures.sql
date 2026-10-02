-- ==============================================================================
-- Report 06: Transaction Counts, Status & Payment Failures
-- Business Purpose: Operational monitoring of transaction processing health,
-- highlighting cancellation and failure rates across payment methods.
-- ==============================================================================

SELECT 
    f.payment_method,
    COUNT(f.sales_key) AS total_attempts,
    SUM(CASE WHEN f.transaction_status = 'Completed' THEN 1 ELSE 0 END) AS completed_count,
    SUM(CASE WHEN f.transaction_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_count,
    SUM(CASE WHEN f.transaction_status = 'Refunded' THEN 1 ELSE 0 END) AS refunded_count,
    SUM(CASE WHEN f.transaction_status = 'Failed' THEN 1 ELSE 0 END) AS failed_count,
    -- Failure / Issue Rate Percentage
    ROUND(
        100.0 * SUM(CASE WHEN f.transaction_status = 'Failed' THEN 1 ELSE 0 END) / NULLIF(COUNT(f.sales_key), 0),
        2
    ) AS failure_rate_pct,
    -- Lost / Failed Revenue Value
    SUM(CASE WHEN f.transaction_status = 'Failed' THEN f.net_amount ELSE 0 END) AS lost_failed_revenue
FROM edw.fact_sales f
GROUP BY 
    f.payment_method
ORDER BY 
    total_attempts DESC;
