"""
Synthetic Data Generator for Retail Sales Portfolio Project
Generates realistic retail transactions and dimension datasets.
Includes controlled data quality anomalies (nulls, duplicates, invalid values)
to demonstrate data cleaning and pipeline validation.
"""

import csv
import datetime
import os
import random

random.seed(42)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_RAW_DIR = os.path.join(BASE_DIR, "data", "raw")
DATA_SAMPLE_DIR = os.path.join(BASE_DIR, "data", "sample")

os.makedirs(DATA_RAW_DIR, exist_ok=True)
os.makedirs(DATA_SAMPLE_DIR, exist_ok=True)

# 1. Dimension: Regions
REGIONS = [
    {"region_id": 1, "region_name": "North America - East", "country": "United States", "manager_name": "Sarah Jenkins"},
    {"region_id": 2, "region_name": "North America - West", "country": "United States", "manager_name": "David Martinez"},
    {"region_id": 3, "region_name": "Europe - Central", "country": "Germany", "manager_name": "Hans Schmidt"},
    {"region_id": 4, "region_name": "Europe - West", "country": "United Kingdom", "manager_name": "Emma Watson"},
    {"region_id": 5, "region_name": "Asia Pacific", "country": "Singapore", "manager_name": "Wei Chen"}
]

# 2. Dimension: Stores
STORES = [
    {"store_id": "STR-101", "store_name": "Downtown Manhattan Flagship", "region_id": 1, "city": "New York", "store_type": "Flagship"},
    {"store_id": "STR-102", "store_name": "Boston Back Bay Store", "region_id": 1, "city": "Boston", "store_type": "Standard"},
    {"store_id": "STR-103", "store_name": "Seattle Downtown Outlet", "region_id": 2, "city": "Seattle", "store_type": "Outlet"},
    {"store_id": "STR-104", "store_name": "San Francisco Union Sq", "region_id": 2, "city": "San Francisco", "store_type": "Flagship"},
    {"store_id": "STR-105", "store_name": "Berlin Alexanderplatz", "region_id": 3, "city": "Berlin", "store_type": "Standard"},
    {"store_id": "STR-106", "store_name": "Munich City Center", "region_id": 3, "city": "Munich", "store_type": "Standard"},
    {"store_id": "STR-107", "store_name": "London Oxford Street", "region_id": 4, "city": "London", "store_type": "Flagship"},
    {"store_id": "STR-108", "store_name": "Manchester Arndale", "region_id": 4, "city": "Manchester", "store_type": "Standard"},
    {"store_id": "STR-109", "store_name": "Singapore Marina Mall", "region_id": 5, "city": "Singapore", "store_type": "Flagship"},
    {"store_id": "STR-110", "store_name": "Sydney George St Store", "region_id": 5, "city": "Sydney", "store_type": "Standard"}
]

# 3. Dimension: Products
PRODUCTS = [
    {"product_id": "PRD-001", "product_name": "Ultra Wireless Noise-Cancelling Headphones", "category": "Electronics", "subcategory": "Audio", "unit_cost": 85.00, "base_price": 149.99},
    {"product_id": "PRD-002", "product_name": "Smart Fitness Tracker Band 5", "category": "Electronics", "subcategory": "Wearables", "unit_cost": 28.00, "base_price": 59.99},
    {"product_id": "PRD-003", "product_name": "4K Ultra-HD Action Camera Pro", "category": "Electronics", "subcategory": "Cameras", "unit_cost": 120.00, "base_price": 229.99},
    {"product_id": "PRD-004", "product_name": "Ergonomic Mesh Office Chair", "category": "Home & Office", "subcategory": "Furniture", "unit_cost": 95.00, "base_price": 189.99},
    {"product_id": "PRD-005", "product_name": "Stainless Steel Thermal Coffee Tumbler 20oz", "category": "Home & Office", "subcategory": "Drinkware", "unit_cost": 8.50, "base_price": 24.99},
    {"product_id": "PRD-006", "product_name": "Organic Cotton Crewneck T-Shirt", "category": "Apparel", "subcategory": "Men's Clothing", "unit_cost": 7.00, "base_price": 19.99},
    {"product_id": "PRD-007", "product_name": "Water-Resistant Trail Hiking Jacket", "category": "Apparel", "subcategory": "Outerwear", "unit_cost": 45.00, "base_price": 99.99},
    {"product_id": "PRD-008", "product_name": "Breathable Athletic Running Shoes", "category": "Footwear", "subcategory": "Sports Footwear", "unit_cost": 38.00, "base_price": 89.99},
    {"product_id": "PRD-009", "product_name": "Compact Mechanical Gaming Keyboard", "category": "Electronics", "subcategory": "Computer Accessories", "unit_cost": 42.00, "base_price": 79.99},
    {"product_id": "PRD-010", "product_name": "Eco-Friendly Yoga Mat 6mm", "category": "Sports & Fitness", "subcategory": "Fitness Accessories", "unit_cost": 12.00, "base_price": 29.99}
]

PAYMENT_METHODS = ["Credit Card", "Debit Card", "Mobile Wallet", "Cash", "Gift Card"]
TRANSACTION_STATUSES = ["Completed", "Completed", "Completed", "Completed", "Completed", "Cancelled", "Refunded", "Failed"]

def write_csv(filepath, fieldnames, rows):
    with open(filepath, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Generated {len(rows)} records -> {filepath}")

def generate_dimensions():
    # Save regions
    write_csv(
        os.path.join(DATA_SAMPLE_DIR, "dim_regions.csv"),
        ["region_id", "region_name", "country", "manager_name"],
        REGIONS
    )
    # Save stores
    write_csv(
        os.path.join(DATA_SAMPLE_DIR, "dim_stores.csv"),
        ["store_id", "store_name", "region_id", "city", "store_type"],
        STORES
    )
    # Save products
    write_csv(
        os.path.join(DATA_SAMPLE_DIR, "dim_products.csv"),
        ["product_id", "product_name", "category", "subcategory", "unit_cost", "base_price"],
        PRODUCTS
    )
    # Save calendar dates for 2026
    start_date = datetime.date(2026, 9, 1)
    calendar_rows = []
    for i in range(60): # 60 days
        curr = start_date + datetime.timedelta(days=i)
        calendar_rows.append({
            "date_key": int(curr.strftime("%Y%m%d")),
            "full_date": curr.strftime("%Y-%m-%d"),
            "day_name": curr.strftime("%A"),
            "day_of_week": curr.weekday() + 1,
            "day_of_month": curr.day,
            "month_num": curr.month,
            "month_name": curr.strftime("%B"),
            "quarter": f"Q{(curr.month - 1) // 3 + 1}",
            "year": curr.year,
            "is_weekend": 1 if curr.weekday() >= 5 else 0
        })
    write_csv(
        os.path.join(DATA_SAMPLE_DIR, "dim_calendar.csv"),
        ["date_key", "full_date", "day_name", "day_of_week", "day_of_month", "month_num", "month_name", "quarter", "year", "is_weekend"],
        calendar_rows
    )

def generate_daily_transactions():
    store_map = {s["store_id"]: s for s in STORES}
    region_map = {r["region_id"]: r["region_name"] for r in REGIONS}
    
    dates = [
        datetime.date(2026, 9, 28),
        datetime.date(2026, 9, 29),
        datetime.date(2026, 9, 30),
        datetime.date(2026, 10, 1),
        datetime.date(2026, 10, 2)
    ]
    
    txn_counter = 10001
    
    for dt in dates:
        dt_str = dt.strftime("%Y-%m-%d")
        file_dt = dt.strftime("%Y%m%d")
        daily_records = []
        
        num_records = random.randint(45, 65)
        
        for _ in range(num_records):
            store = random.choice(STORES)
            product = random.choice(PRODUCTS)
            qty = random.randint(1, 6)
            unit_price = product["base_price"]
            
            # Apply occasional realistic discounts (0%, 5%, 10%, 15%)
            discount_pct = random.choice([0.0, 0.0, 0.0, 0.05, 0.10, 0.15])
            raw_gross = qty * unit_price
            discount = round(raw_gross * discount_pct, 2)
            
            status = random.choice(TRANSACTION_STATUSES)
            pm = random.choice(PAYMENT_METHODS)
            
            txn_id = f"TXN-{file_dt}-{txn_counter:05d}"
            txn_counter += 1
            
            record = {
                "transaction_id": txn_id,
                "transaction_date": dt_str,
                "store_id": store["store_id"],
                "store_name": store["store_name"],
                "region": region_map[store["region_id"]],
                "product_id": product["product_id"],
                "product_name": product["product_name"],
                "category": product["category"],
                "quantity": qty,
                "unit_price": f"{unit_price:.2f}",
                "discount": f"{discount:.2f}",
                "payment_method": pm,
                "transaction_status": status
            }
            daily_records.append(record)
        
        # Inject controlled anomalies into 2-3 records per file to test data cleansing & validation
        if len(daily_records) > 5:
            # 1. Introduce a duplicate transaction ID
            duplicate_rec = dict(daily_records[2])
            daily_records.append(duplicate_rec)
            
            # 2. Introduce a record with missing store_id or invalid quantity for testing filtering
            corrupt_rec = dict(daily_records[4])
            corrupt_rec["transaction_id"] = f"TXN-{file_dt}-{txn_counter:05d}"
            txn_counter += 1
            corrupt_rec["quantity"] = -1 # Invalid quantity
            daily_records.append(corrupt_rec)
            
            # 3. Introduce a record with null discount (to test null-to-zero coalescing)
            null_disc_rec = dict(daily_records[6])
            null_disc_rec["transaction_id"] = f"TXN-{file_dt}-{txn_counter:05d}"
            txn_counter += 1
            null_disc_rec["discount"] = "" # Empty/null discount
            daily_records.append(null_disc_rec)

        fieldnames = [
            "transaction_id", "transaction_date", "store_id", "store_name",
            "region", "product_id", "product_name", "category",
            "quantity", "unit_price", "discount", "payment_method", "transaction_status"
        ]
        
        out_path = os.path.join(DATA_RAW_DIR, f"daily_transactions_{file_dt}.csv")
        write_csv(out_path, fieldnames, daily_records)

if __name__ == "__main__":
    print("Generating Dimension datasets...")
    generate_dimensions()
    print("Generating Daily Raw Transaction files...")
    generate_daily_transactions()
    print("Synthetic data generation completed successfully.")
