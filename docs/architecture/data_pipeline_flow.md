# Data Pipeline Flow & Execution Lifecycle

## End-to-End Execution Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    participant Scheduler as ADF Schedule Trigger (Daily 02:00 UTC)
    participant ADF as Azure Data Factory Pipeline
    participant BlobRaw as Azure Blob (Raw Container)
    participant Databricks as Azure Databricks (PySpark)
    participant BlobCurated as Azure Blob (Curated Container)
    participant SQLStaging as Azure SQL (stg.daily_sales_transactions)
    participant SQLEDW as Azure SQL (edw.fact_sales)
    participant OpsLog as Azure SQL (ops.pipeline_execution_logs)

    Scheduler->>ADF: Fire Trigger with parameter trigger_date = YYYY-MM-DD
    ADF->>BlobRaw: Activity 1: Validate daily_transactions_YYYYMMDD.csv exists
    BlobRaw-->>ADF: File Exists & Size Valid
    
    ADF->>Databricks: Activity 2: Run Notebook 01_data_cleaning_and_transformation
    Databricks->>BlobRaw: Read raw CSV dataset
    Databricks->>Databricks: Cleanse, Filter Bad Records, Deduplicate, Compute Derived Fields
    Databricks->>BlobCurated: Write Curated Parquet to /curated-transactions/date=YYYYMMDD
    Databricks-->>ADF: Notebook Execution Status: SUCCESS (Metrics JSON)

    ADF->>Databricks: Activity 3: Run Notebook 02_data_quality_validation
    Databricks->>BlobCurated: Read Curated Parquet
    Databricks->>Databricks: Assert DQ Rules (Nulls, Duplicates, Positive Ranges, Valid Statuses)
    Databricks-->>ADF: DQ Validation Status: PASSED

    ADF->>SQLStaging: Activity 4: Copy Activity (Parquet -> stg.daily_sales_transactions)
    SQLStaging-->>ADF: Truncate staging & Insert Staged Rows Complete

    ADF->>SQLEDW: Activity 5: Execute Stored Procedure (ops.usp_load_fact_sales)
    SQLEDW->>SQLEDW: Join Staging with Dimensions (Look up Surrogate Keys)
    SQLEDW->>SQLEDW: MERGE into edw.fact_sales (Insert new / Update existing)
    SQLEDW->>SQLStaging: Truncate Staging Table
    SQLEDW->>OpsLog: Log Batch Run Telemetry (Rows Inserted, Updated, Execution Duration)
    SQLEDW-->>ADF: Procedure Executed Successfully
```

---

## Detailed Pipeline Phases

### Phase 1: File Ingestion & Pre-Condition Validation
- **Trigger**: The pipeline is triggered on a daily cadence or manually with parameter `trigger_date` (format: `YYYY-MM-DD`).
- **Validation**: ADF executes a `Validation` activity to verify the daily file `daily_transactions_YYYYMMDD.csv` has landed in the `raw-transactions` container and is non-empty.

### Phase 2: Distributed PySpark Data Transformation
- ADF triggers the Databricks notebook activity.
- The PySpark job executes the following transformations:
  1. Reads raw CSV with explicit `raw_schema`.
  2. Trims all string columns to avoid whitespace matching issues.
  3. Coalesces `NULL` discounts to `0.00`.
  4. Filters out corrupt rows: missing IDs, `quantity <= 0`, negative `unit_price`, and unsupported `transaction_status`.
  5. Deduplicates records on `transaction_id`.
  6. Calculates derived measures:
     $$\text{gross\_amount} = \text{quantity} \times \text{unit\_price}$$
     $$\text{net\_amount} = (\text{quantity} \times \text{unit\_price}) - \text{discount}$$
  7. Persists the clean dataset into partitioned Snappy-compressed Parquet files in `curated-transactions/date=YYYYMMDD`.

### Phase 3: Data Quality Gates
- Databricks notebook `02_data_quality_validation` executes automated assertion checks.
- If any critical check fails (e.g., duplicate transaction IDs or negative net amounts), the pipeline terminates immediately before data touches the relational database.

### Phase 4: Staging Copy
- ADF `Copy Activity` performs high-performance bulk loading from Parquet into `stg.daily_sales_transactions`.
- A pre-copy script cleans any residual staging rows.

### Phase 5: Dimensional Modeling & Idempotent Merge
- ADF calls stored procedure `ops.usp_load_fact_sales`.
- Inside the transaction:
  1. Maps natural business keys (`store_id`, `product_id`, `region`) to dimension surrogate keys (`store_key`, `product_key`, `region_id`).
  2. Executes an atomic `MERGE` statement into `edw.fact_sales`.
  3. Emits audit telemetry into `ops.pipeline_execution_logs`.
  4. Commits the transaction and empties the staging table.
