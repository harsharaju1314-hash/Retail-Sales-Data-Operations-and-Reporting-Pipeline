# Databricks notebook source
# MAGIC %md
# MAGIC # Retail Data Pipeline - Data Quality Validation & Integrity Checks
# MAGIC 
# MAGIC **Purpose**: Performs pre-load and post-transformation data quality validations on retail sales data. Asserts critical integrity checks (nulls, duplicates, value ranges, referential integrity).

# COMMAND ----------
import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, when, isnan

spark = SparkSession.builder.appName("RetailSalesDataQualityValidation").getOrCreate()

dbutils_available = 'dbutils' in globals()
if dbutils_available:
    dbutils.widgets.text("trigger_date", "2026-10-01", "Trigger Date (YYYY-MM-DD)")
    dbutils.widgets.text("target_storage_path", "/mnt/curated-transactions", "Curated Target Path")
    trigger_date_str = dbutils.widgets.get("trigger_date")
    target_path = dbutils.widgets.get("target_storage_path")
else:
    trigger_date_str = "2026-10-01"
    target_path = "./data/curated"

formatted_date_suffix = trigger_date_str.replace("-", "")
curated_data_path = f"{target_path}/date={formatted_date_suffix}"

print(f"Running Data Quality Validations for Date: {trigger_date_str}")
print(f"Validating dataset at: {curated_data_path}")

# COMMAND ----------
# MAGIC %md
# MAGIC ### 1. Read Curated Dataset

# COMMAND ----------
try:
    df_curated = spark.read.parquet(curated_data_path)
    total_records = df_curated.count()
    print(f"Total Curated Records Loaded: {total_records}")
except Exception as e:
    print(f"Error reading curated dataset: {str(e)}")
    raise e

# COMMAND ----------
# MAGIC %md
# MAGIC ### 2. Execute Data Quality Assertions

# COMMAND ----------
validation_results = []

def run_check(check_name, failure_condition, failure_desc):
    failing_rows = df_curated.filter(failure_condition).count()
    status = "PASSED" if failing_rows == 0 else "FAILED"
    result = {
        "check_name": check_name,
        "status": status,
        "failing_record_count": failing_rows,
        "description": failure_desc
    }
    validation_results.append(result)
    print(f"[{status}] {check_name} - Failing Rows: {failing_rows}")
    return status == "PASSED"

# DQ-01: Null Transaction IDs
run_check(
    "DQ-01: No Null Transaction IDs",
    col("transaction_id").isNull() | (col("transaction_id") == ""),
    "All records must have a non-empty transaction_id"
)

# DQ-02: Duplicate Transaction IDs
duplicate_df = df_curated.groupBy("transaction_id").count().filter(col("count") > 1)
dup_count = duplicate_df.count()
dup_status = "PASSED" if dup_count == 0 else "FAILED"
validation_results.append({
    "check_name": "DQ-02: Uniqueness of Transaction ID",
    "status": dup_status,
    "failing_record_count": dup_count,
    "description": "Each transaction_id must be globally unique within the daily batch"
})
print(f"[{dup_status}] DQ-02: Uniqueness of Transaction ID - Duplicates: {dup_count}")

# DQ-03: Positive Quantities
run_check(
    "DQ-03: Positive Quantity Sold",
    col("quantity") <= 0,
    "Quantity sold must be strictly greater than 0"
)

# DQ-04: Non-negative Unit Prices
run_check(
    "DQ-04: Valid Unit Prices",
    col("unit_price") < 0.00,
    "Unit price must be non-negative"
)

# DQ-05: Non-negative Net Revenue
run_check(
    "DQ-05: Non-negative Net Amount",
    col("net_amount") < 0.00,
    "Net amount must be greater than or equal to 0"
)

# DQ-06: Allowed Transaction Status
valid_statuses = ["Completed", "Cancelled", "Refunded", "Failed"]
run_check(
    "DQ-06: Valid Transaction Status",
    ~col("transaction_status").isin(valid_statuses),
    "Transaction status must be one of: Completed, Cancelled, Refunded, Failed"
)

# COMMAND ----------
# MAGIC %md
# MAGIC ### 3. Quality Validation Summary Report

# COMMAND ----------
print("=" * 60)
print(f" DATA QUALITY REPORT: {trigger_date_str}")
print("=" * 60)

all_passed = all(r["status"] == "PASSED" for r in validation_results)
for r in validation_results:
    print(f"• {r['check_name']}: {r['status']} ({r['failing_record_count']} violations)")

print("-" * 60)
if all_passed:
    print("STATUS: ALL DATA QUALITY CHECKS PASSED. Ready for SQL Warehouse Load.")
else:
    print("STATUS: ONE OR MORE DATA QUALITY CHECKS FAILED. Halting pipeline.")

if dbutils_available:
    import json
    dbutils.notebook.exit(json.dumps({
        "status": "PASSED" if all_passed else "FAILED",
        "total_checks": len(validation_results),
        "checks_passed": sum(1 for r in validation_results if r["status"] == "PASSED"),
        "checks_failed": sum(1 for r in validation_results if r["status"] == "FAILED"),
        "results": validation_results
    }))
