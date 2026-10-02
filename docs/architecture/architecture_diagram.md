# Architecture & Data Pipeline Overview

## High-Level Architecture Diagram

```mermaid
flowchart TD
    subgraph Ingestion_Layer["1. Source & Ingestion Layer"]
        A[Synthetic Daily CSV Files] -->|Upload / Blob Trigger| B[(Azure Blob Storage\nraw-transactions)]
    end

    subgraph Orchestration_Layer["2. Orchestration Layer"]
        ADF[Azure Data Factory\npl_daily_retail_sales_ingestion]
    end

    subgraph Processing_Layer["3. Transformation & Cleansing Layer"]
        B -.->|Read Raw CSV| ADB[Azure Databricks\nPySpark Transformation]
        ADB -->|Validate, Clean, Deduplicate & Derive Metrics| C[(Azure Blob Storage\ncurated-transactions Parquet)]
    end

    subgraph Warehouse_Layer["4. Enterprise Data Warehouse (Azure SQL)"]
        C -->|Copy Activity| STG[(stg.daily_sales_transactions)]
        STG -->|usp_load_fact_sales MERGE| EDW[(edw.fact_sales)]
        DIM1[(edw.dim_date)] -.->|Surrogate Key Lookup| EDW
        DIM2[(edw.dim_store)] -.->|Surrogate Key Lookup| EDW
        DIM3[(edw.dim_product)] -.->|Surrogate Key Lookup| EDW
        DIM4[(edw.dim_region)] -.->|Surrogate Key Lookup| EDW
        EDW -->|Execution Telemetry| OPS[(ops.pipeline_execution_logs)]
    end

    subgraph BI_Reporting_Layer["5. Analytics & BI Reporting Layer"]
        EDW --> Q1[01. Daily Sales Summary]
        EDW --> Q2[02. Regional Performance & Share]
        EDW --> Q3[03. Store Format Comparison]
        EDW --> Q4[04. Category Margin Analysis]
        EDW --> Q5[05. Top-Selling Products DENSE_RANK]
        EDW --> Q6[06. Payment Method & Failure Analysis]
        EDW --> Q7[07. 3-Day Moving Avg & Revenue Trend]
    end

    ADF -->|1. Validate File Exists| B
    ADF -->|2. Trigger Notebook| ADB
    ADF -->|3. Copy Parquet to Staging| STG
    ADF -->|4. Execute Stored Procedure| EDW
```

---

## Architectural Breakdown

### 1. Ingestion Layer (Azure Blob Storage)
- Stores daily incoming sales transactions in CSV format: `daily_transactions_YYYYMMDD.csv`.
- Serves as the immutable raw landing zone.

### 2. Orchestration Layer (Azure Data Factory)
- Coordinates and monitors execution dependencies.
- Handles automated daily schedule triggering, parameter injection, activity retries, and error notifications.

### 3. Transformation & Cleaning Layer (Azure Databricks / PySpark)
- **Schema Enforcement & Casting**: Explicit PySpark schema preventing schema drift.
- **Data Cleansing**: Trimming strings, coalescing null discounts to `0.00`, standardizing date formats.
- **Quality Filtering**: Drops invalid quantities (`quantity <= 0`), negative unit prices, and unrecognized transaction statuses.
- **Deduplication**: Eliminates duplicate `transaction_id` occurrences using window partitioning.
- **Derived Metrics**: Calculates `gross_amount` and `net_amount` (`(quantity * unit_price) - discount`).
- **Curated Export**: Persists clean data in partitioned Snappy-compressed Parquet files.

### 4. Enterprise Data Warehouse Layer (Azure SQL Database)
- **Staging Table (`stg.daily_sales_transactions`)**: High-throughput transient holding area loaded directly from Parquet.
- **Dimensional Star Schema (`edw`)**:
  - `dim_date`: Calendar lookup for time-intelligence reporting.
  - `dim_region`: Geographic hierarchy and regional manager attribution.
  - `dim_store`: Store location, format (Flagship/Standard/Outlet), and regional mapping.
  - `dim_product`: Product catalog, hierarchy, category, and standard unit costs.
  - `fact_sales`: Granular transaction fact table holding quantities, revenues, discounts, and foreign keys.
- **Idempotent Upsert (`ops.usp_load_fact_sales`)**: Uses SQL `MERGE` to prevent duplicate transaction entries when pipeline batches re-run.
- **Operational Auditing (`ops.pipeline_execution_logs`)**: Records row counts, pipeline run IDs, status, and execution duration.

### 5. BI Reporting Layer (SQL Analytics & Power BI)
- Modular analytical queries demonstrating standard business reporting metrics.
- Uses Common Table Expressions (CTEs), Aggregations, Conditional `CASE` expressions, and Analytical Window Functions (`ROW_NUMBER`, `DENSE_RANK`, `LAG`, `AVG() OVER`).
