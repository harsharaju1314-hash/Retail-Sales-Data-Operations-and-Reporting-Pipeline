-- ==============================================================================
-- 05_load_fact_sales_from_staging.sql
-- Description: Stored Procedure to perform idempotent load/upsert from staging
--              into edw.fact_sales with audit logging into ops.pipeline_execution_logs.
-- ==============================================================================

IF OBJECT_ID('ops.usp_load_fact_sales', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_load_fact_sales;
GO

CREATE PROCEDURE ops.usp_load_fact_sales
    @trigger_date DATE,
    @pipeline_run_id VARCHAR(100) = 'MANUAL_EXECUTION'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
    DECLARE @DateKey INT = YEAR(@trigger_date) * 10000 + MONTH(@trigger_date) * 100 + DAY(@trigger_date);
    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsUpdated INT = 0;
    DECLARE @RowsRejected INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX) = NULL;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Identify and count records in staging that lack matching dimension records (Foreign Key Integrity Check)
        SELECT @RowsRejected = COUNT(*)
        FROM stg.daily_sales_transactions s
        LEFT JOIN edw.dim_store ds ON s.store_id = ds.store_id
        LEFT JOIN edw.dim_product dp ON s.product_id = dp.product_id
        LEFT JOIN edw.dim_region dr ON s.region = dr.region_name
        WHERE ds.store_key IS NULL 
           OR dp.product_key IS NULL 
           OR dr.region_id IS NULL;

        -- 2. Merge staged data into fact_sales
        -- Using MERGE ensures idempotency: if the pipeline re-runs for the same day, data is updated instead of duplicated.
        ;WITH CleanStagedSource AS (
            SELECT 
                s.transaction_id,
                @DateKey AS date_key,
                ds.store_key,
                dp.product_key,
                dr.region_id,
                s.quantity,
                s.unit_price,
                s.discount AS discount_amount,
                s.gross_amount,
                s.net_amount,
                s.payment_method,
                s.transaction_status
            FROM stg.daily_sales_transactions s
            INNER JOIN edw.dim_store ds ON s.store_id = ds.store_id
            INNER JOIN edw.dim_product dp ON s.product_id = dp.product_id
            INNER JOIN edw.dim_region dr ON s.region = dr.region_name
            WHERE s.transaction_date = @trigger_date
        )
        MERGE INTO edw.fact_sales AS target
        USING CleanStagedSource AS source
        ON target.transaction_id = source.transaction_id
        WHEN MATCHED THEN
            UPDATE SET 
                target.date_key = source.date_key,
                target.store_key = source.store_key,
                target.product_key = source.product_key,
                target.region_id = source.region_id,
                target.quantity = source.quantity,
                target.unit_price = source.unit_price,
                target.discount_amount = source.discount_amount,
                target.gross_amount = source.gross_amount,
                target.net_amount = source.net_amount,
                target.payment_method = source.payment_method,
                target.transaction_status = source.transaction_status,
                target.updated_at = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (
                transaction_id,
                date_key,
                store_key,
                product_key,
                region_id,
                quantity,
                unit_price,
                discount_amount,
                gross_amount,
                net_amount,
                payment_method,
                transaction_status,
                created_at,
                updated_at
            )
            VALUES (
                source.transaction_id,
                source.date_key,
                source.store_key,
                source.product_key,
                source.region_id,
                source.quantity,
                source.unit_price,
                source.discount_amount,
                source.gross_amount,
                source.net_amount,
                source.payment_method,
                source.transaction_status,
                SYSUTCDATETIME(),
                SYSUTCDATETIME()
            );

        -- Capture row modification counts
        SET @RowsInserted = @@ROWCOUNT;

        -- 3. Truncate staging table for the processed batch
        TRUNCATE TABLE stg.daily_sales_transactions;

        COMMIT TRANSACTION;

        -- 4. Log successful execution
        DECLARE @EndTime DATETIME2 = SYSUTCDATETIME();
        INSERT INTO ops.pipeline_execution_logs (
            pipeline_name,
            run_id,
            trigger_date,
            step_name,
            rows_inserted,
            rows_updated,
            rows_rejected,
            status,
            error_message,
            start_time,
            end_time,
            execution_duration_sec
        )
        VALUES (
            'pl_daily_retail_sales_ingestion',
            @pipeline_run_id,
            @trigger_date,
            'usp_load_fact_sales',
            @RowsInserted,
            @RowsUpdated,
            @RowsRejected,
            'SUCCESS',
            NULL,
            @StartTime,
            @EndTime,
            DATEDIFF(SECOND, @StartTime, @EndTime)
        );

        PRINT 'Data Warehouse Load Successful: ' + CAST(@RowsInserted AS VARCHAR(10)) + ' rows processed.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrorMessage = ERROR_MESSAGE();
        DECLARE @ErrorEndTime DATETIME2 = SYSUTCDATETIME();

        -- Log failure to operations audit table
        INSERT INTO ops.pipeline_execution_logs (
            pipeline_name,
            run_id,
            trigger_date,
            step_name,
            rows_inserted,
            rows_updated,
            rows_rejected,
            status,
            error_message,
            start_time,
            end_time,
            execution_duration_sec
        )
        VALUES (
            'pl_daily_retail_sales_ingestion',
            @pipeline_run_id,
            @trigger_date,
            'usp_load_fact_sales',
            0,
            0,
            0,
            'FAILED',
            @ErrorMessage,
            @StartTime,
            @ErrorEndTime,
            DATEDIFF(SECOND, @StartTime, @ErrorEndTime)
        );

        THROW;
    END CATCH
END;
GO
