

# Airflow Project Root Directory: Orchestration Layer

This directory is the **Apache Airflow orchestration layer root directory** of the "ETL-Pipeline" project. Created and managed using the Astro CLI, this structure handles the scheduling, execution, and monitoring of all data integration and transformation workflows in the project.

The files and folders here define the dependencies, DAGs, plugins, and general runtime settings of the Airflow environment.

## Directory Structure and Key Components

Below are the main directories and files of this Airflow project and their roles within the project:

* **`.astro/`**

  * Contains configuration files specific to Astro CLI. These files are necessary for Astro CLI to recognize your project and manage the Airflow environment with commands like `astro dev start`. Typically, these files are not directly edited.

* **`.vscode/`**

  * Contains settings and extension configurations specific to the Visual Studio Code editor. It aims to facilitate easy setup of your development environment and provide the best practice experience for Airflow projects.

* **`dags/`**

  * **The main directory where Apache Airflow DAG (Directed Acyclic Graph) files are stored.**
  * All data workflows (orchestration of Extract, Load, Transform steps) of the project are defined here as Python files (`.py`).
  * Example: The `etl_transactional_all_tables.py` DAG file contains critical steps like loading data from AWS S3 to Snowflake, triggering dbt transformations, and logging metadata.
  * To create a new data workflow or modify an existing one, the corresponding DAG files in this directory are edited.

* **`include/`**

  * Contains additional files that can be used by Airflow DAGs or other components (e.g., custom SQL scripts, helper Python modules, parsers for processing dbt outputs).
  * Files in this directory are automatically included in the Airflow runtime environment and can be imported by DAGs.

* **`logs/`**

  * Directory where runtime logs produced by Airflow schedulers and workers are stored. Includes details of DAG executions, task success/failure statuses, and error messages.
  * This is a critical source for debugging and monitoring pipeline processes.

* **`plugins/`**

  * Directory for custom Apache Airflow plugins, operators, sensors, or hooks.
  * Project-specific extensions or reusable Airflow components are defined here.

* **`.env`**

  * Defines environment variables for the local development environment. This file should be included in `.gitignore` and must not contain sensitive information (API keys, database passwords). Instead, use Airflow Connections or Secret Management systems.

* **`Dockerfile`**

  * Defines the **Astro Runtime Docker image and customizations** used for this project.
  * Ensures a consistent Airflow runtime environment by including project dependencies (Python packages, OS packages).
  * Includes necessary operating system dependencies (from `packages.txt`) and Python dependencies (from `requirements.txt`) into the Docker image.

* **`README.md`**

  * This file (the one you are currently reading) explains the purpose, structure, and interaction methods of the Airflow project root directory.

* **`airflow_settings.yaml`**

  * Used to configure fundamental Airflow settings such as Connections, Variables, and Pools in the **local development environment**.
  * This file reduces the need to manually enter settings through the Airflow UI by avoiding the inclusion of sensitive data directly in the codebase. Usually, it should be added to `.gitignore` or use placeholders for sensitive information.

* **`packages.txt`**

  * Lists additional operating system (OS) packages (e.g., `git`, `unixodbc-dev`) to be included in the Airflow environment’s Docker image. Read by the `Dockerfile`.

* **`requirements.txt`**

  * Lists all required **Python library dependencies** for Airflow DAGs and the Airflow environment itself. Installed automatically during Docker image build or via `pip install -r requirements.txt`.

## Setting Up and Running the Local Development Environment

To develop and test this Airflow project directory on your local machine, follow these steps:

1. **Prerequisites:**

   * **Docker Desktop:** Ensure Docker and Docker Compose are installed and running on your system.
   * **Astro CLI:** The Astronomer Command Line Interface (CLI) must be installed. For installation instructions, visit the [Astro CLI Documentation](https://docs.astronomer.io/astro/cli/install-cli).

2. **Navigate to the Project Directory:**

   ```bash
   cd ETL-Pipeline/assets/project
   ```

3. **Start the Airflow Environment:**

   * This command will build/update the Astro Runtime Docker image according to definitions in `Dockerfile` and `requirements.txt`, and start Airflow services (webserver, scheduler, worker, Postgres, Redis) inside Docker containers.

   ```bash
   astro dev start
   ```

   * After successful startup, you can usually access the Airflow Webserver at `http://localhost:8080`. Default credentials: `admin`/`admin`.

4. **Configure Airflow Settings:**

   * Ensure that the project’s database connections (e.g., Snowflake Connection) and variables are configured in the local Airflow environment via the `airflow_settings.yaml` file.
   * Sensitive information (API keys, passwords) should not be stored directly in `.env` or `airflow_settings.yaml`. Use secure methods such as Airflow Secrets Backend or CI/CD variables instead.

5. **Test DAGs:**

   * Through the Airflow UI, you can enable DAGs in the `dags/` directory and test by manually triggering them or waiting for their scheduled runs.
   * DAG execution logs can be viewed in the `logs/` directory or via the Airflow UI.

## Dependency Management

* **Python Dependencies:** The `requirements.txt` file specifies the Python library dependencies of the project. Update this file when adding new dependencies.
* **Operating System Dependencies:** The `packages.txt` file lists OS-level packages to be included in the Docker image.

