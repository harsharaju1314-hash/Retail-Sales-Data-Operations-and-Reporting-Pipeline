# Data Quality Validation Rules & Anomaly Handling

To ensure warehouse reliability and trustworthy BI reporting, data validations are enforced across two strategic stages:
1. **PySpark Pre-Load Validation (Databricks Layer)**: Filters anomalies before landing in curated storage.
2. **Referential & Schema Integrity (Azure SQL Warehouse Layer)**: Ensures relational constraints and idempotency during the staging merge.

---

## Data Quality Rule Matrix

| Rule ID | Rule Name | Target Column(s) | Validation Logic / Constraint | Action on Failure |
| :--- | :--- | :--- | :--- | :--- |
| **DQ-01** | Mandatory Key Integrity | `transaction_id`, `transaction_date`, `store_id`, `product_id` | Value is not `NULL` and string is not empty `""` | Record dropped; logged to rejected counter |
| **DQ-02** | Transaction ID Uniqueness | `transaction_id` | Deduplicate on `transaction_id`; keep latest record per batch | Duplicates filtered out; duplicate counter incremented |
| **DQ-03** | Valid Quantity Range | `quantity` | `quantity > 0` | Record dropped; flagged as invalid volume |
| **DQ-04** | Valid Price Range | `unit_price` | `unit_price >= 0.00` | Record dropped; flagged as pricing anomaly |
| **DQ-05** | Discount Coalescing & Bounds | `discount` | If `NULL` -> default to `0.00`. Ensure `net_amount >= 0.00` | Coalesced to `0.00`; negative net capped at `0.00` |
| **DQ-06** | Valid Transaction Status | `transaction_status` | Must belong to: `{'Completed', 'Cancelled', 'Refunded', 'Failed'}` | Record dropped; unrecognized status rejected |
| **DQ-07** | Date Format & Range | `transaction_date` | Must parse cleanly into valid `DateType` (`YYYY-MM-DD`) | Invalid dates dropped |
| **DQ-08** | Referential Integrity Check | `store_id`, `product_id`, `region` | Must match valid dimension records in `dim_store`, `dim_product`, `dim_region` | Logged to `rows_rejected` in `ops.pipeline_execution_logs` |

---

## Detailed Handling Strategies

### 1. Handling Missing Optional Values (e.g. Discount)
- In the raw retail CSV files, certain promotional transactions may have empty string or `NULL` discount values.
- **Handling Strategy**: The PySpark transformation applies `coalesce(col("discount"), lit(0.00))` to guarantee calculations succeed without generating `NULL` net revenues.

### 2. Handling Duplicate Transactions
- Network retries or multiple POS transmissions can occasionally send duplicate rows with identical `transaction_id`.
- **Handling Strategy**: Databricks applies window partitioning `row_number().over(Window.partitionBy("transaction_id").orderBy(col("transaction_date").desc()))` and retains only row 1.

### 3. Handling Corrupt Numeric Quantities or Negative Prices
- An entry with negative quantities (e.g., `-1` resulting from an unhandled return entry in legacy systems) or negative prices is rejected at the PySpark layer.
- **Handling Strategy**: Filtered out in PySpark step 4, preventing corrupt data from entering the warehouse.

### 4. Referential Integrity Failures
- If a daily transaction references a store or product code not yet registered in the dimension tables, the SQL Stored Procedure `ops.usp_load_fact_sales` performs an inner join against dimensions, logs the rejected row count to `ops.pipeline_execution_logs`, and ensures only clean, referentially sound rows are merged into `edw.fact_sales`.
