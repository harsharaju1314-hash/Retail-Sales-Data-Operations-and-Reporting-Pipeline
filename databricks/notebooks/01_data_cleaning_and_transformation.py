# Databricks notebook source
# MAGIC %md
# MAGIC # Retail Data Pipeline - Daily Transaction Cleaning & Transformation
# MAGIC 
# MAGIC **Author**: Junior Data Operations Engineer  
# MAGIC **Purpose**: Ingest raw daily transaction CSVs from Azure Blob Storage, apply data validation and business transformations, compute derived metrics (`gross_amount`, `net_amount`), and write clean curated Parquet datasets for Azure SQL Data Warehouse loading.

# COMMAND ----------
# MAGIC %md
# MAGIC ### 1. Setup Parameters & Widgets
# MAGIC Parameters can be passed dynamically from Azure Data Factory pipeline activities.

# COMMAND ----------
import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, trim, when, lit, round as spark_round, 
    to_date, current_timestamp, row_number, coalesce
)
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, 
    DecimalType, DateType
)
from pyspark.sql.window import Window

# Initialize or get Spark session
spark = SparkSession.builder.appName("RetailSalesDataTransformation").getOrCreate()

# Retrieve parameters from ADF or use default for development/local execution
dbutils_available = 'dbutils' in globals()

if dbutils_available:
    dbutils.widgets.text("trigger_date", "2026-10-01", "Trigger Date (YYYY-MM-DD)")
    dbutils.widgets.text("source_storage_path", "/mnt/raw-transactions", "Raw Source Path")
    dbutils.widgets.text("target_storage_path", "/mnt/curated-transactions", "Curated Target Path")
    
    trigger_date_str = dbutils.widgets.get("trigger_date")
    source_path = dbutils.widgets.get("source_storage_path")
    target_path = dbutils.widgets.get("target_storage_path")
else:
    # Fallback for local/CI test runs
    trigger_date_str = "2026-10-01"
    source_path = "./data/raw"
    target_path = "./data/curated"

print(f"Executing Batch Transformation for Date: {trigger_date_str}")
print(f"Source Path: {source_path}")
print(f"Target Path: {target_path}")

# COMMAND ----------
# MAGIC %md
# MAGIC ### 2. Define Explicit Schema & Ingest Raw Data

# COMMAND ----------
raw_schema = StructType([
    StructField("transaction_id", StringType(), True),
    StructField("transaction_date", StringType(), True),
    StructField("store_id", StringType(), True),
    StructField("store_name", StringType(), True),
    StructField("region", StringType(), True),
    StructField("product_id", StringType(), True),
    StructField("product_name", StringType(), True),
    StructField("category", StringType(), True),
    StructField("quantity", IntegerType(), True),
    StructField("unit_price", DecimalType(10, 2), True),
    StructField("discount", DecimalType(10, 2), True),
    StructField("payment_method", StringType(), True),
    StructField("transaction_status", StringType(), True)
])

# Determine daily file pattern (e.g., daily_transactions_20261001.csv)
formatted_date_suffix = trigger_date_str.replace("-", "")
raw_file_path = f"{source_path}/daily_transactions_{formatted_date_suffix}.csv"

print(f"Reading source file: {raw_file_path}")

df_raw = spark.read \
    .option("header", "true") \
    .schema(raw_schema) \
    .csv(raw_file_path)

total_raw_records = df_raw.count()
print(f"Total Raw Records Ingested: {total_raw_records}")

# COMMAND ----------
# MAGIC %md
# MAGIC ### 3. Data Cleaning & Handling Null / Invalid Values
# MAGIC - Trim leading/trailing whitespace across string fields
# MAGIC - Handle missing discount values by replacing `NULL` with `0.00`
# MAGIC - Cast `transaction_date` to standard SQL `DateType`
# MAGIC - Ensure default values for required non-nullable fields

# COMMAND ----------
df_cleaned = df_raw \
    .withColumn("transaction_id", trim(col("transaction_id"))) \
    .withColumn("transaction_date", to_date(col("transaction_date"), "yyyy-MM-dd")) \
    .withColumn("store_id", trim(col("store_id"))) \
    .withColumn("store_name", trim(col("store_name"))) \
    .withColumn("region", trim(col("region"))) \
    .withColumn("product_id", trim(col("product_id"))) \
    .withColumn("product_name", trim(col("product_name"))) \
    .withColumn("category", trim(col("category"))) \
    .withColumn("payment_method", trim(col("payment_method"))) \
    .withColumn("transaction_status", trim(col("transaction_status"))) \
    .withColumn("discount", coalesce(col("discount"), lit(0.00)))

# COMMAND ----------
# MAGIC %md
# MAGIC ### 4. Data Quality Filtering & Anomaly Handling
# MAGIC Filter out corrupt records:
# MAGIC 1. Missing transaction_id, transaction_date, store_id, or product_id
# MAGIC 2. Non-positive quantities (`quantity <= 0`)
# MAGIC 3. Negative unit prices (`unit_price < 0`)
# MAGIC 4. Invalid transaction status (must be one of: Completed, Cancelled, Refunded, Failed)

# COMMAND ----------
valid_statuses = ["Completed", "Cancelled", "Refunded", "Failed"]

# Flag invalid records
df_validated = df_cleaned.filter(
    col("transaction_id").isNotNull() & (col("transaction_id") != "") &
    col("transaction_date").isNotNull() &
    col("store_id").isNotNull() & (col("store_id") != "") &
    col("product_id").isNotNull() & (col("product_id") != "") &
    (col("quantity") > 0) &
    (col("unit_price") >= 0.00) &
    col("transaction_status").isin(valid_statuses)
)

records_after_quality_filter = df_validated.count()
invalid_records_count = total_raw_records - records_after_quality_filter
print(f"Records Passing Quality Rules: {records_after_quality_filter} (Rejected: {invalid_records_count})")

# COMMAND ----------
# MAGIC %md
# MAGIC ### 5. Deduplication
# MAGIC Deduplicate on `transaction_id`. If duplicate IDs occur in the batch, retain the single most complete/first entry.

# COMMAND ----------
window_spec = Window.partitionBy("transaction_id").orderBy(col("transaction_date").desc())

df_deduped = df_validated \
    .withColumn("row_num", row_number().over(window_spec)) \
    .filter(col("row_num") == 1) \
    .drop("row_num")

records_after_dedup = df_deduped.count()
duplicate_count = records_after_quality_filter - records_after_dedup
print(f"Records After Deduplication: {records_after_dedup} (Duplicates Removed: {duplicate_count})")

# COMMAND ----------
# MAGIC %md
# MAGIC ### 6. Business Transformations & Derived Calculations
# MAGIC Calculate:
# MAGIC - `gross_amount = quantity * unit_price`
# MAGIC - `net_amount = (quantity * unit_price) - discount`
# MAGIC - Ingestion audit timestamp: `processed_timestamp`

# COMMAND ----------
df_transformed = df_deduped \
    .withColumn("gross_amount", spark_round(col("quantity") * col("unit_price"), 2)) \
    .withColumn("net_amount", spark_round((col("quantity") * col("unit_price")) - col("discount"), 2)) \
    .withColumn("processed_timestamp", current_timestamp())

# Ensure net_amount is never negative due to anomaly discount
df_final = df_transformed.withColumn(
    "net_amount", 
    when(col("net_amount") < 0.00, lit(0.00)).otherwise(col("net_amount"))
)

# COMMAND ----------
# MAGIC %md
# MAGIC ### 7. Write Curated Dataset to Storage
# MAGIC Write output as Parquet format for downstream loading into Azure SQL Database.

# COMMAND ----------
output_curated_path = f"{target_path}/date={formatted_date_suffix}"

print(f"Writing curated dataset to: {output_curated_path}")

df_final.write \
    .mode("overwrite") \
    .parquet(output_curated_path)

print(f"Transformation Complete. Successfully wrote {df_final.count()} records.")

# COMMAND ----------
# MAGIC %md
# MAGIC ### 8. Return Execution Summary
# MAGIC Return status metrics to ADF caller.

# COMMAND ----------
execution_metrics = {
    "status": "SUCCESS",
    "trigger_date": trigger_date_str,
    "raw_records_read": total_raw_records,
    "invalid_records_rejected": invalid_records_count,
    "duplicates_removed": duplicate_count,
    "curated_records_written": df_final.count()
}

print("Execution Summary:")
for k, v in execution_metrics.items():
    print(f"  {k}: {v}")

if dbutils_available:
    import json
    dbutils.notebook.exit(json.dumps(execution_metrics))
