#  End-to-End ELT Pipeline with Dashboards

![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/diagram.svg)

## Table of Contents

* Project Introduction
  * Steps
  * Transformation Logic
  * Metadata Tracking


## Project Introduction

This project was developed for a small e-commerce business aiming to automate and streamline its data analytics workflow. The company manages core operational data such as customers, orders, products, and order_items, which are stored in AWS S3 as raw files. Using a modern ELT approach, this data is ingested into Snowflake, transformed using dbt, and visualized with Tableau.

The pipeline was designed to replace a previously manual process that took up to 3 hours per day to clean, transform, and report on data. With this fully automated architecture, the same process is now completed in approximately 12 minutes, significantly reducing operational overhead and enabling more timely decision-making.

The workflow runs daily at 11:00 PM, ensuring up-to-date metrics for the next business day. A dedicated dashboard was also built in Tableau to monitor dbt job logs, execution durations, and data freshness—providing transparency and traceability throughout the entire pipeline.


## Steps

### 1. Data Collection

The raw data is initially stored in **AWS S3**, organized by domain-specific folders such as `customers`, `orders`, `products`, and `order_items`. Airflow triggers a daily process to extract the latest data from S3 and prepares it for loading.

### 2. Data Loading

Using **Snowflake External Stage** and **MERGE** operations, the raw data is ingested into staging tables in Snowflake. This process ensures high-speed, scalable loading of large-volume CSV/JSON files into the data warehouse.

### 3. Data Transformation

Data is then modeled and transformed using **dbt**. The transformation logic includes:

* Renaming and standardizing raw fields
* Building `staging` and `mart` layers
* Creating business-ready tables such as `customer_order_summary`
* Implementing data quality tests and documenting lineage

### 4. Data Visualization

Key business metrics—such as daily revenue, customer count, order volume, and category performance—are visualized using **Tableau dashboards**. These dashboards also include operational views for tracking pipeline runs and dbt model performance over time.

### 5. Automation and Scheduling

The entire pipeline is orchestrated via **Apache Airflow**, and scheduled to run **daily at 11:00 PM**. This ensures that the latest data is available every morning for analysis and decision-making.

### 6. Time Efficiency & Logging

The full pipeline now runs in approximately **12 minutes**, compared to the previous manual process which took around **3 hours**. This not only improves efficiency, but also ensures consistency and traceability. dbt logs and execution metadata are tracked and visualized to monitor model health and run durations.


## DAG Structure

![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/dag_stracure.png)

### 1. Data Pull

* **Purpose**: Retrieve raw data from **AWS S3** (CSV format) and stage it into Snowflake.

* **Method**:

  * Uses `COPY INTO` to load data into temporary `*_raw` tables via a Snowflake External Stage.
  * Supports schema-aligned ingestion for `orders`, `order_items`, `products`, and `customers`.

* **Error Handling**:

  * The process runs inside a `BEGIN ... COMMIT` block to ensure atomicity.
  * On failure, it executes a `ROLLBACK`.


### 2. Data Transformation

* **Purpose**: Apply business logic to raw data and create clean, analytics-ready tables.

* **Method**:

  * The `dbt` project handles transformations using **modular SQL models**.
  * Implements staging and mart layers, and applies data tests (e.g., null checks, uniqueness, referential integrity).
  * Executed via `DbtTaskGroup` within Airflow using Cosmos integration.

* **Output**: Models like `customer_order_summary`, `daily_sales`, and category-based aggregations.



### 3. Metadata Logging

* **Purpose**: Track dbt model runs, execution durations, and success/failure status.

* **Method**:

  * `run_results.json` is parsed after dbt execution.
  * Metadata is inserted into a dedicated Snowflake table `dbt_metadata_log`, including:

    * `unique_id`, `model_name`, `status`, `execution_time`, `execution_date`, `batch_id`

* **Usage**:

  * Used in Tableau to monitor pipeline health and model performance over time.



### 4. Scheduling and Dependencies

* **Execution Time**: Scheduled to run **daily at 23:00** (`0 11 * * *` UTC).
* **DAG Flow**:

  ```
  generate_batch_id
         ↓
  etl_orders_group
         ↓
  etl_order_items_group
         ↓
  etl_customers_group
         ↓
  etl_products_group
         ↓
  dbt_transactional_group
         ↓
  log_dbt_metadata
  ```
* **Retries**:

  * Each task has 1 retry with a 3-minute delay.
  * Failures trigger an **email alert** with detailed logs and direct log URL for investigation.


## DBT Structure

![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/dbt_sctature.png)

## Snapshot

### Monthly Metrics Summary
![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/metrics_sum.png)

### DBT Log Tracker Dashboard
![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/dbt_log.png)
