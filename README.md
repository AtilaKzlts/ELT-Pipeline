<div align="center">
  <h1>End-to-End ELT Pipeline with Dashboards</h1>
 </p>
</div>


![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/diagram.svg)

## Table of Contents

  * Project Introduction
  * Steps
  * DAG Structure
  * DBT Structure
  

## Project Introduction


This project was developed for a small e-commerce business aiming to automate and streamline its data analytics workflow. The company manages core operational data such as customers, orders, products, and order_items, which are stored in AWS S3 as raw files. Using a modern ELT approach, this data is ingested into Snowflake, transformed using dbt, and visualized with Tableau.

The pipeline was designed to replace a previously manual process that took up to 3 hours per day to clean, transform, and report on data. With this fully automated architecture, the same process is now completed in approximately 12 minutes, significantly reducing operational overhead and enabling more timely decision-making.

The workflow runs daily at 11:00 PM, ensuring up-to-date metrics for the next business day. A dedicated Tableau dashboard was also built to monitor dbt job logs, execution durations, and data freshness—providing transparency and traceability throughout the entire pipeline.

To ensure reliability, the system is configured to send email notifications in case of any pipeline failure. These alerts contain detailed logs and direct links to help stakeholders quickly investigate and resolve issues.


## Steps

### 1. Data Collection

Raw data is initially stored in **AWS S3**, organized into domain-specific folders such as `customers`, `orders`, `products`, and `order_items`. **Airflow triggers a daily process** to extract the latest data from S3 and prepare it for loading into the data warehouse.

### 2. Data Loading

Using **Snowflake External Stage** and **MERGE operations**, raw data is ingested into staging tables in Snowflake. During this step, the system **compares current data with the previous day's data** and only loads **new or modified records**. This ensures high-speed and scalable ingestion of large-volume CSV/JSON files into the warehouse.

### 3. Data Transformation

The data is then modeled and transformed using **dbt**. The transformation logic includes:

* Renaming and standardizing raw fields
* Building **staging** and **mart** layers
* Creating business-ready tables such as `customer_order_summary`
* Applying **data quality tests** and documenting model lineage

### 4. Data Visualization

We built a **"Monthly Metrics" dashboard** to visualize business KPIs updated monthly, powered directly by Snowflake.
Additionally, we created a **"dbt Log Tracker" dashboard** to monitor pipeline executions, track model run durations, and identify errors or outliers over time. This enables easier debugging and operational transparency.

### 5. Automation & Scheduling

The entire pipeline is orchestrated with **Apache Airflow**, scheduled to run **daily at 11:00 PM**. This ensures that the latest data is always available for analysis the next morning.

### 6. Time Efficiency & Logging

The pipeline now runs in approximately **12 minutes**, compared to the previous **manual process that took nearly 3 hours**.
This not only improves efficiency but also enhances consistency and traceability.
All **dbt logs and execution metadata** are tracked and visualized to monitor model health and performance over time.

## DAG Structure

![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/dag_stracure.png)

*Airflow DAG: `etl_transactional_all_tables` Overview*

**1. Data Ingestion and Transactional ETL**

* **Purpose:** To pull raw CSV data from AWS S3 into Snowflake and ensure data integrity by merging (UPSERTing) or inserting new records into existing tables. Each operation is executed within a database transaction to guarantee atomic completion of all steps.
* **Method:**
    * **Batch ID Generation:** A unique `batch_id` is generated at the DAG's start. This ID is associated with relevant ETL and metadata records, enabling data traceability.
    * **Data Copy and Merge:** A `PythonOperator` (`run_transactional_etl`) within a dedicated `TaskGroup` is used for each source table (orders, order\_items, customers, products). This operator copies CSV files from S3 to temporary `_raw` tables in Snowflake. Subsequently, it uses `MERGE INTO` commands to integrate (update or insert) data from the `_raw` tables into the main tables (e.g., `dbt_schema.orders`). These steps occur within a single database transaction; in case of any error, the entire transaction is rolled back (`ROLLBACK`).
    * **Raw Table Truncation:** After a successful merge operation, the corresponding `_raw` table is truncated, preparing it for the next load.
* **Error Handling:** Each ETL task operates within a `BEGIN...COMMIT...ROLLBACK` block, guaranteeing data consistency.

**2. Data Transformation (dbt)**

* **Purpose:** To apply complex business logic and transformations on the clean, merged data residing in Snowflake, creating final, analytics-ready data models.
* **Method:**
    * **dbt Project:** The dbt project located at `/usr/local/airflow/dags/dbt/air_dbt` manages transformations and tests through modular SQL models.
    * **Cosmos Integration:** The `DbtTaskGroup` (`dbt_transactional_group`) handles the dbt execution environment and commands within Airflow. The `install_deps=False` and `dbt_deps=False` settings assume that dependencies are pre-installed, which improves runtime performance.
* **Dependencies:** dbt transformations begin only after all transactional ETL groups have successfully completed.

**3. Metadata Logging**

* **Purpose:** To maintain a comprehensive record of dbt model runs, including execution durations and success/failure statuses.
* **Method:**
    * **`run_results.json` Parsing:** The `parse_and_log_dbt_metadata` Python function reads and parses the `run_results.json` file, which dbt generates after its execution.
    * **Snowflake Logging:** The extracted metadata (e.g., `unique_id`, `model_name`, `status`, `execution_time`, `execution_date`, and crucially, the **`batch_id`**) is then inserted into the `dbt_schema.dbt_metadata_log` table. This `batch_id` integration significantly enhances traceability by linking dbt runs to a specific ETL workflow.
* **Usage:** The collected metadata can be utilized in BI tools like Tableau to monitor pipeline health, model performance, and data lineage.

**Email Notifications:**

* The DAG is configured with an `on_failure_callback` using the `notify_email` function. This function sends a detailed HTML-formatted email to `atilla094409@gmail.com` if the DAG fails, instantly alerting operators and providing a direct link to Airflow UI logs.


## DBT Structure

![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/dbt_sctature.png)

* **`customers_summary.sql`**: This model provides essential customer contact and demographic details, including age, gender, and location. It also includes useful transformations such as email domain extraction and gender data cleansing.
  
* **`customer_metrics.sql`**: This mart offers a detailed analysis of customer purchasing habits, spending amounts, and return rates. It segments customers into categories like "VIP" and "High_Value" and defines lifecycle stages such as "Active" and "Lost," guiding targeted marketing strategies.
  
* **`monthly_sales_summary.sql`**: This model presents key macro sales performance indicators on a monthly basis, including total order count, total expenditure, and the number of unique customers.
* **`products_performance.sql`**: This mart delivers crucial sales performance metrics for each product, such as gross and net revenue, units sold, and average discount rates. It sorts products by net revenue to identify top performers.
* **`order_items_summary.sql`**: This model summarizes daily order item data, including total quantity, revenue, and discount amounts. It is utilized to monitor daily sales trends at the order item level.
* **`customer_order_summary.sql`**: This mart consolidates each customer's total order count and total spending in one place. It also provides the customer's first and last order dates, aiding in understanding their activity duration.
* **`payment_method_analysis.sql`**: This model analyzes which payment methods are most frequently used and the total revenue generated by each.
* **`customer_retention_churn.sql`**: This mart provides a foundational framework for tracking customer retention rates by monitoring monthly new and returning customer counts. It serves as a starting point for customer lifecycle analysis.
* **`geographical_performance.sql`**: This model evaluates geographical sales performance by presenting total orders, revenue, and unique customer counts per country and city. It is crucial for understanding regional sales disparities and opportunities.

## Snapshot

### Monthly Metrics Summary
![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/Admin_Dashboard.png)

### DBT Log Tracker Dashboard
![image](https://github.com/AtilaKzlts/ETL-Pipeline/blob/main/assets/dbt_log.png)
