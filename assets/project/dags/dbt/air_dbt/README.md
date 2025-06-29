# Data Transformation Layer

This directory is the root directory of the **dbt (data build tool)** project for the "ETL-Pipeline" project. It is responsible for transforming our raw data (located in the staging layer in Snowflake) into reliable, modeled datasets ready for business analysis and reporting.

dbt enables version control, testing, and documentation of SQL-based transformations, making the transformation processes in the data warehouse more manageable and reliable.

## Directory Structure and Key Components

Below are the main directories and files of this dbt project and their roles within the project:

* **`analyses/`**
    * Contains dbt SQL files used for one-off or exploratory analyses. These models are typically used to test dbt’s compiled code or quickly answer specific business questions, and usually have no dependencies on downstream models.

* **`macros/`**
    * Houses reusable, parameterized SQL snippets (templated with `Jinja`) that can be called inside dbt models.
    * Defines repetitive SQL logic centrally to reduce code duplication and ensure consistency in data transformations. For example, frequently used date functions or table-specific filter logic can be defined here as macros.

* **`models/`**
    * **The core directory containing the data transformation logic of the dbt project.**
    * Each SQL file (`.sql`) creates or updates a table or view in Snowflake.
    * This directory is usually organized into subfolders such as `staging`, `intermediate`, and `marts`:
        * **`staging/`**: Contains models that are close to raw data, applying basic cleaning and transformation steps (e.g., renaming columns, basic type casting).
        * **`marts/`**: Contains business-specific, aggregated, and combined datasets optimized for analysis and reporting. (For example, models like `customers_summary.sql`, `monthly_sales_summary.sql` reside here.)
    * Our data modeling process defines analytical models such as `customers_summary.sql`, `customer_metrics.sql`, `monthly_sales_summary.sql`, as described in this README.

* **`seeds/`**
    * Contains CSV files of static or small datasets manually loaded into the database (e.g., country codes, category definitions, lookup tables).
    * These files can be loaded into the database using the `dbt run` command and referenced in models.

* **`snapshots/`**
    * Contains dbt snapshot definitions that capture point-in-time representations of source tables and track changes over time.
    * Used for data lineage tracking or implementing Slowly Changing Dimensions Type 2 (SCD Type 2).

* **`tests/`**
    * Contains YAML or SQL files defining data quality tests for dbt models.
    * Used to verify data integrity (e.g., `not_null`, `unique`), referential integrity (e.g., `relationships`), and custom business rules. A critical component for ensuring data reliability.

* **`.gitignore`**
    * Specifies files and directories excluded from Git version control (e.g., compiled dbt artifacts, logs, sensitive configuration files).

* **`README.md`**
    * This file (currently being read) explaining the purpose, structure, and interaction methods of the dbt project.

* **`dbt_project.yml`**
    * **The main configuration file of the dbt project.**
    * Defines project name, model paths, macro paths, snapshot configurations, test settings, data warehouse target configurations (referencing `profiles.yml`), and default materialization strategies (table, view, ephemeral, incremental) for models.

* **`package-lock.yml`**
    * Locks exact versions of dbt packages defined in `packages.yml` (external dbt projects or macros/models downloaded from dbt hub), ensuring consistent dependency resolution.

* **`packages.yml`**
    * Defines external dbt packages used by this dbt project, allowing you to incorporate macros or models developed by others.

## Setting Up and Running the Local Development Environment

To develop, test, and run this dbt project locally, follow these steps:

1.  **Start the Airflow Environment:**
    * Since this dbt project is called by Airflow DAGs, first ensure the Airflow environment is running in the `ETL-Pipeline/assets/project` directory. (Refer to the main project `README` or `/assets/project/README.md`.)

2.  **Install dbt CLI (If Needed):**
    * The `astro dev start` command already includes dbt inside the Astro Runtime. However, if you want to use dbt independently, you might need to install dbt-core and the Snowflake adapter in your Python environment:
        ```bash
        pip install dbt-snowflake dbt-core
        ```

3.  **Configure dbt Profiles:**
    * dbt requires a `profiles.yml` file to connect to your Snowflake database. This file usually resides outside the project (e.g., at `~/.dbt/profiles.yml`) and contains your database credentials.
    * Example `profiles.yml` (replace sensitive info with your credentials or manage via Airflow Connections):
        ```yaml
        air_dbt:
          target: dev
          outputs:
            dev:
              type: snowflake
              account: <your_snowflake_account>
              user: <your_snowflake_user>
              password: <your_snowflake_password>
              role: <your_snowflake_role>
              database: <your_snowflake_database>
              warehouse: <your_snowflake_warehouse>
              schema: <your_snowflake_schema>
              threads: 4
              client_session_keep_alive: False
        ```
    * **NOTE:** When running dbt via Airflow, these `profiles.yml` settings are usually overridden by Airflow connections. This file is critical for local dbt development and testing.

4.  **Run dbt Commands:**
    * Navigate to the project directory:
        ```bash
        cd ETL-Pipeline/assets/project/dags/dbt/air_dbt
        ```
    * **Validate dbt Settings:**
        ```bash
        dbt debug
        ```
    * **Compile Models:**
        ```bash
        dbt compile
        ```
    * **Run Models (Load into Database):**
        ```bash
        dbt run
        ```
    * **Run Tests:**
        ```bash
        dbt test
        ```
    * **Generate and Serve Documentation:**
        ```bash
        dbt docs generate
        dbt docs serve
        ```
        (This will open a web-based documentation of your dbt models in your browser.)

## Data Models and Layering

The data models in our `models/` directory follow a layered approach from staging to marts optimized for business analysis:

* **Staging Layer:** Contains basic cleaning, filtering, and normalization of data coming from raw data sources.
* **Mart Layer:** Contains aggregated, business-logic-applied final datasets designed to be used directly by business analysts and reporting tools. (Examples: `customers_summary`, `monthly_sales_summary`, `products_performance`, etc.)

## Contributing

To contribute to this dbt project:

1.  Use the appropriate directory (`models/`, `macros/`) to create new dbt models or macros.
2.  Write data quality tests in the `tests/` directory for new or existing models.
3.  Enrich documentation by updating model schemas and descriptions in YAML files.
4.  Test your changes (`dbt run --select <model_name>`, `dbt test`).
5.  Commit your changes to version control and open a Pull Request in the main repository.


