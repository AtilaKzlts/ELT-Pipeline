# OWNER: Atilla KIZILTAS
# DATE: 2025-06-23

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.utils.email import send_email
from airflow.utils.task_group import TaskGroup
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig, RenderConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping
from datetime import datetime, timedelta
import uuid
import os
import json

# ✅ 1. Generate a unique batch ID
def generate_batch_id(**kwargs):
    batch_id = str(uuid.uuid4())
    kwargs['ti'].xcom_push(key='batch_id', value=batch_id)

# ✅ 2. Parse and log DBT metadata with the batch_id
def parse_and_log_dbt_metadata(**kwargs):
    results_path = "/usr/local/airflow/dags/dbt/air_dbt/target/run_results.json"
    batch_id = kwargs['ti'].xcom_pull(task_ids='generate_batch_id', key='batch_id')

    if not os.path.exists(results_path):
        raise FileNotFoundError(f"run_results.json not found: {results_path}")

    with open(results_path, "r") as file:
        data = json.load(file)

    results = data.get("results", [])
    if not results:
        raise ValueError("No results found in run_results.json.")

    hook = SnowflakeHook(snowflake_conn_id="snow_conn")
    conn = hook.get_conn()
    cursor = conn.cursor()

    for result in results:
        unique_id = result.get("unique_id")
        status = result.get("status")
        execution_time = result.get("execution_time")
        execution_date = datetime.utcnow()

        model_name = unique_id.split(".")[2] if unique_id else "unknown"

        insert_stmt = """
            INSERT INTO dbt_schema.dbt_metadata_log
            (unique_id, model_name, status, execution_time, execution_date, batch_id)
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        cursor.execute(insert_stmt, (
            unique_id,
            model_name,
            status,
            execution_time,
            execution_date,
            batch_id
        ))

    cursor.close()
    conn.close()
    print("DBT metadata successfully logged into Snowflake.")

# ✅ Email Notification Function
def notify_email(context):
    dag_run = context.get("dag_run")
    task_instance = context.get("task_instance")
    exception = context.get("exception")
    status = dag_run.get_state()
    subject = f"[Airflow] DAG {dag_run.dag_id} - Status: {status.upper()}"

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; background-color: #f9f9f9; color: #333; }}
            .container {{ padding: 20px; border: 1px solid #ddd; border-radius: 8px; background-color: #fff; }}
            a.button {{ display: inline-block; padding: 10px 15px; background-color: #007bff; color: #fff; text-decoration: none; border-radius: 5px; }}
            a.button:hover {{ background-color: #0056b3; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h2>Airflow DAG Notification</h2>
            <p><strong>DAG:</strong> {dag_run.dag_id}</p>
            <p><strong>Status:</strong> {status.upper()}</p>
            <p><a class="button" href="{task_instance.log_url}" target="_blank">View Task Logs</a></p>
        </div>
    </body>
    </html>
    """

    send_email(
        to=["atilla094409@gmail.com"], # Target email address
        subject=subject,
        html_content=html_content
    )

# Cosmos DBT profile configuration
profile_config = ProfileConfig(
    profile_name="default",
    target_name="dev",
    profile_mapping=SnowflakeUserPasswordProfileMapping(
        conn_id="snow_conn", # Snowflake connection detail from ui
        profile_args={"database": "dbt_db", "schema": "dbt_schema"},
    ),
)

# Transactional ETL Function
def run_transactional_etl(table_config, **kwargs):
    hook = SnowflakeHook(snowflake_conn_id='snow_conn')
    conn = hook.get_conn()
    cursor = conn.cursor()
    batch_id = kwargs['ti'].xcom_pull(task_ids='generate_batch_id', key='batch_id')
    try:
        cursor.execute("BEGIN;")
        cursor.execute(table_config['copy_sql'])
        merge_sql = table_config['merge_sql'].format(batch_id=batch_id)
        cursor.execute(merge_sql)
        cursor.execute(table_config['truncate_sql'])
        cursor.execute("COMMIT;")
    except Exception as e:
        cursor.execute("ROLLBACK;")
        raise e
    finally:
        cursor.close()
        conn.close()

tables = [
     {
        "table_name": "orders",
        "copy_sql": """
            COPY INTO dbt_schema.orders_raw FROM @my_s3_stage/orders.csv
            FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
            ON_ERROR = 'CONTINUE';
        """,
        "merge_sql": """
            MERGE INTO dbt_schema.orders AS target
            USING dbt_schema.orders_raw AS source
            ON target.ORDER_ID = source.ORDER_ID
            WHEN MATCHED THEN UPDATE SET
                target.CUSTOMER_ID = source.CUSTOMER_ID,
                target.ORDER_DATE = source.ORDER_DATE,
                target.SHIPPING_ADDRESS = source.SHIPPING_ADDRESS,
                target.ORDER_STATUS = source.ORDER_STATUS,
                target.PAYMENT_METHOD = source.PAYMENT_METHOD,
                target.TOTAL_AMOUNT = source.TOTAL_AMOUNT,
                target.batch_id = '{batch_id}'
            WHEN NOT MATCHED THEN INSERT (ORDER_ID, CUSTOMER_ID, ORDER_DATE, SHIPPING_ADDRESS, ORDER_STATUS, PAYMENT_METHOD, TOTAL_AMOUNT, batch_id)
            VALUES (source.ORDER_ID, source.CUSTOMER_ID, source.ORDER_DATE, source.SHIPPING_ADDRESS, source.ORDER_STATUS, source.PAYMENT_METHOD, source.TOTAL_AMOUNT, '{batch_id}');
        """,
        "truncate_sql": "TRUNCATE TABLE dbt_schema.orders_raw;"
    },
    {
        "table_name": "order_items",
        "copy_sql": """
            COPY INTO dbt_schema.order_items_raw FROM @my_s3_stage/order_items.csv
            FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
            ON_ERROR = 'CONTINUE';
        """,
        "merge_sql": """
            MERGE INTO dbt_schema.order_items AS target
            USING dbt_schema.order_items_raw AS source
            ON target.ORDER_ITEM_ID = source.ORDER_ITEM_ID
            WHEN MATCHED THEN UPDATE SET
                target.ORDER_ID = source.ORDER_ID,
                target.PRODUCT_ID = source.PRODUCT_ID,
                target.QUANTITY = source.QUANTITY,
                target.UNIT_PRICE = source.UNIT_PRICE,
                target.DISCOUNT = source.DISCOUNT,
                target.batch_id = '{batch_id}'
            WHEN NOT MATCHED THEN INSERT (ORDER_ITEM_ID, ORDER_ID, PRODUCT_ID, QUANTITY, UNIT_PRICE, DISCOUNT, batch_id)
            VALUES (source.ORDER_ITEM_ID, source.ORDER_ID, source.PRODUCT_ID, source.QUANTITY, source.UNIT_PRICE, source.DISCOUNT, '{batch_id}');
        """,
        "truncate_sql": "TRUNCATE TABLE dbt_schema.order_items_raw;"
    },
    {
        "table_name": "customers",
        "copy_sql": """
            COPY INTO dbt_schema.customer_raw FROM @my_s3_stage/customers.csv
            FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
            ON_ERROR = 'CONTINUE';
        """,
        "merge_sql": """
            MERGE INTO dbt_schema.customer AS target
            USING dbt_schema.customer_raw AS source
            ON target.CUSTOMER_ID = source.CUSTOMER_ID
            WHEN MATCHED THEN UPDATE SET
                target.FIRST_NAME = source.FIRST_NAME,
                target.LAST_NAME = source.LAST_NAME,
                target.EMAIL = source.EMAIL,
                target.GENDER = source.GENDER,
                target.DATE_OF_BIRTH = source.DATE_OF_BIRTH,
                target.REGISTRATION_DATE = source.REGISTRATION_DATE,
                target.COUNTRY = source.COUNTRY,
                target.CITY = source.CITY,
                target.batch_id = '{batch_id}'
            WHEN NOT MATCHED THEN INSERT (CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, GENDER, DATE_OF_BIRTH, REGISTRATION_DATE, COUNTRY, CITY, batch_id)
            VALUES (source.CUSTOMER_ID, source.FIRST_NAME, source.LAST_NAME, source.EMAIL, source.GENDER, source.DATE_OF_BIRTH, source.REGISTRATION_DATE, source.COUNTRY, source.CITY, '{batch_id}');
        """,
        "truncate_sql": "TRUNCATE TABLE dbt_schema.customer_raw;"
    },
    {
        "table_name": "products",
        "copy_sql": """
            COPY INTO dbt_schema.products_raw FROM @my_s3_stage/products.csv
            FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
            ON_ERROR = 'CONTINUE';
        """,
        "merge_sql": """
            MERGE INTO dbt_schema.products AS target
            USING dbt_schema.products_raw AS source
            ON target.PRODUCT_ID = source.PRODUCT_ID
            WHEN MATCHED THEN UPDATE SET
                target.PRODUCT_NAME = source.PRODUCT_NAME,
                target.CATEGORY = source.CATEGORY,
                target.BRAND = source.BRAND,
                target.PRICE = source.PRICE,
                target.CURRENCY = source.CURRENCY,
                target.IS_ACTIVE = source.IS_ACTIVE,
                target.batch_id = '{batch_id}'
            WHEN NOT MATCHED THEN INSERT (PRODUCT_ID, PRODUCT_NAME, CATEGORY, BRAND, PRICE, CURRENCY, IS_ACTIVE, batch_id)
            VALUES (source.PRODUCT_ID, source.PRODUCT_NAME, source.CATEGORY, source.BRAND, source.PRICE, source.CURRENCY, source.IS_ACTIVE, '{batch_id}');
        """,
        "truncate_sql": "TRUNCATE TABLE dbt_schema.products_raw;"
    }
] 

# DAG definition
default_args = {
    "owner": "atilla",
    "retries": 1,
    "retry_delay": timedelta(minutes=3),
}

with DAG(
    dag_id="etl_transactional_all_tables",
    default_args=default_args,
    start_date=datetime(2025, 6, 1),
    schedule_interval="0 11 * * *",
    catchup=False,
    tags=["dbt", "snowflake","s3"],
    on_failure_callback=notify_email
) as dag:

    generate_batch = PythonOperator(
        task_id="generate_batch_id",
        python_callable=generate_batch_id
    )

    etl_task_groups = []
    for table in tables:
        with TaskGroup(group_id=f"etl_{table['table_name']}_group") as tg:
            task = PythonOperator(
                task_id=f"insert_{table['table_name']}_transactional",
                python_callable=run_transactional_etl,
                op_kwargs={"table_config": table},
                provide_context=True
            )
        etl_task_groups.append(tg)

    dbt_group = DbtTaskGroup(
        group_id="dbt_transactional_group",
        project_config=ProjectConfig("/usr/local/airflow/dags/dbt/air_dbt"),
        profile_config=profile_config,
        execution_config=ExecutionConfig(dbt_executable_path="/usr/local/airflow/dbt_venv/bin/dbt"),
        render_config=RenderConfig(dbt_deps=False),
        operator_args={"install_deps": False}
    )

    log_meta_data = PythonOperator(
        task_id='log_dbt_metadata',
        python_callable=parse_and_log_dbt_metadata,
        provide_context=True
    )

    generate_batch >> etl_task_groups[0]
    for i in range(len(etl_task_groups) - 1):
        etl_task_groups[i] >> etl_task_groups[i + 1]

    etl_task_groups[-1] >> dbt_group >> log_meta_data
