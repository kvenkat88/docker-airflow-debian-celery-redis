# Health Docker with Apache Airflow

This repository contains **Dockerfile** of to build the health check docker using Apache Airflow, Docker Compose for creating/running scheduler, celery queue(flower for
celery resources management) and Redis(Celery broker to maintain the celery queue info and status).

## Informations

* Based on Python (3.8-slim-buster) official Image [python:3.8-slim-buster](https://hub.docker.com/_/python/) and uses the official [Postgres](https://hub.docker.com/_/postgres/) as backend and [Redis](https://hub.docker.com/_/redis/) as queue
* Install [Docker](https://www.docker.com/)
* Install [Docker Compose](https://docs.docker.com/compose/install/)
* Following the Airflow release from [Python Package Index](https://pypi.python.org/pypi/apache-airflow)

## Build
create a logs directory and database directory have data and logs sub directory inside that.

Optionally install [Extra Airflow Packages](https://airflow.apache.org/docs/stable/installation.html#extra-package) and/or python dependencies at build time :

    docker build --rm --build-arg AIRFLOW_DEPS="datadog,dask" -t health-checker:<some_version or unique identifier> .
    docker build --rm --build-arg PYTHON_DEPS="flask_oauthlib>=0.9" -t health-checker:<some_version or unique identifier> .

or combined

    docker build --rm --build-arg AIRFLOW_DEPS="datadog,dask" --build-arg PYTHON_DEPS="flask_oauthlib>=0.9" -t health-checker:<some_version or unique identifier> .

Don't forget to update the airflow images in the docker-compose files to health-checker:<some_version or unique identifier>.

## Usage

By default, docker-airflow runs Airflow with **SequentialExecutor** :

    docker run --rm -it -d -p 8080:8080 health-checker:<some_version or unique identifier> webserver

If you want to run another executor, use the other docker-compose.yml files provided in this repository.

For **CeleryExecutor** :
    docker-compose -f docker-compose-CeleryExecutor.yml up -d

NB : If you want to have DAGs example loaded (default=False), you've to set the following environment variable :

`LOAD_EX=n`

    docker run -d -p 8080:8080 -e LOAD_EX=y health-checker:<some_version or unique identifier>

If you want to use Ad hoc query, make sure you've configured connections:
Go to Admin -> Connections and Edit "postgres_default" set this values (equivalent to values in airflow.cfg/docker-compose*.yml) :
- Host : postgres
- Schema : airflow
- Login : airflow
- Password : airflow

For encrypted connection passwords (in Local or Celery Executor), you must have the same fernet_key. By default docker-airflow generates the fernet_key at startup, you have to set an environment variable in the docker-compose (ie: docker-compose-LocalExecutor.yml) file to set the same key accross containers. To generate a fernet_key :

    docker run health-checker:<some_version or unique identifier> python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)"

And env file with config setting for Airflow (used in docker-compose-with-celery-executor.yml): **[.env](.env)**

![Main Apache Airflow UI](./docs/img/airflow_ui.png?raw=true "Main Apache Airflow UI")

![Main Apache Airflow UI](./docs/img/airflow_ui.png?raw=true "Main Apache Airflow UI")

![Version](./docs/img/version.png?raw=true "Airflow Version Screen")

![Celery Flower Dashboard](./docs/img/celery_flower_dashboard.png?raw=true "Celery Flower Dashboard")

Follow the following folder structure while building and deploying the docker image in local,

![Local Folder Structure](./docs/img/folder_structure.png?raw=true "Local Folder Structure")

## Docker Container files/folder structure defined in Dockerfile

Check mainly whether logs and dags folder is available.

![Docker Container Folder Structure](./docs/img/docker_container_folder_structure.png?raw=true "Docker Container Folder Structure")

Once docker image is built and containers are started, we will the containers running image(in sample image am running airflow with 3 workers)

![Sample Containers Running](./docs/img/sample_containers_run.png?raw=true "Sample Containers Running")

## Configuring Airflow

It's possible to set any configuration value for Airflow from environment variables, which are used over values from the airflow.cfg.

The general rule is the environment variable should be named `AIRFLOW__<section>__<key>`, for example `AIRFLOW__CORE__SQL_ALCHEMY_CONN` sets the `sql_alchemy_conn` config option in the `[core]` section.

Check out the [Airflow documentation](http://airflow.readthedocs.io/en/latest/howto/set-config.html#setting-configuration-options) for more details.

You can also define connections via environment variables by prefixing them with `AIRFLOW_CONN_` - for example `AIRFLOW_CONN_POSTGRES_MASTER=postgres://user:password@localhost:5432/master` for a connection called "postgres_master". The value is parsed as a URI. This will work for hooks etc, but won't show up in the "Ad-hoc Query" section unless an (empty) connection is also created in the DB

## Custom Airflow plugins

Airflow allows for custom user-created plugins which are typically found in `${AIRFLOW_HOME}/plugins` folder. Documentation on plugins can be found [here](https://airflow.apache.org/plugins.html)

In order to incorporate plugins into your docker container
- Create the plugins folders `plugins/` with your custom plugins.
- Mount the folder as a volume by doing either of the following:
    - Include the folder as a volume in command-line `-v $(pwd)/plugins/:/usr/local/airflow/plugins`
    - Use docker-compose-LocalExecutor.yml or docker-compose-CeleryExecutor.yml which contains support for adding the plugins folder as a volume

## Install custom python package

- Create a file "requirements.txt" with the desired python modules
- Mount this file as a volume `-v $(pwd)/requirements.txt:/requirements.txt` (or add it as a volume in docker-compose file)
- The entrypoint.sh script execute the pip install command (with --user option)

## UI Links

- Airflow: [localhost:8080](http://localhost:8080/)
- Flower: [localhost:5555](http://localhost:5555/)

## Scale the number of workers

Easy scaling using docker-compose:

    docker-compose -f docker-compose-CeleryExecutor.yml scale worker=5

This can be used to scale to a multi node setup using docker swarm.

## Running other airflow commands

If you want to run other airflow sub-commands, such as `list_dags` or `clear` you can do so like this:

    docker run --rm -ti health-checker:<some_version or unique identifier> airflow list_dags

or with your docker-compose set up like this:

    docker-compose -f docker-compose-CeleryExecutor.yml run --rm webserver airflow list_dags

You can also use this to run a bash shell or any other command in the same environment that airflow would be run in:

    docker run --rm -ti health-checker:<some_version or unique identifier> bash
    docker run --rm -ti health-checker:<some_version or unique identifier> ipython
    

# Simplified SQL database configuration using PostgreSQL

If the executor type is set to anything else than *SequentialExecutor* you'll need an SQL database.
Here is a list of PostgreSQL configuration variables and their default values. They're used to compute
the `AIRFLOW__CORE__SQL_ALCHEMY_CONN` and `AIRFLOW__CELERY__RESULT_BACKEND` variables when needed for you
if you don't provide them explicitly:

| Variable            | Default value |  Role                |
|---------------------|---------------|----------------------|
| `POSTGRES_HOST`     | `postgres`    | Database server host |
| `POSTGRES_PORT`     | `5432`        | Database server port |
| `POSTGRES_USER`     | `airflow`     | Database user        |
| `POSTGRES_PASSWORD` | `airflow`     | Database password    |
| `POSTGRES_DB`       | `airflow`     | Database name        |
| `POSTGRES_EXTRAS`   | empty         | Extras parameters    |

You can also use those variables to adapt your compose file to match an existing PostgreSQL instance managed elsewhere.

Please refer to the Airflow documentation to understand the use of extras parameters, for example in order to configure
a connection that uses TLS encryption.

Here's an important thing to consider:

> When specifying the connection as URI (in AIRFLOW_CONN_* variable) you should specify it following the standard syntax of DB connections,
> where extras are passed as parameters of the URI (note that all components of the URI should be URL-encoded).

Therefore you must provide extras parameters URL-encoded, starting with a leading `?`. For example:

    POSTGRES_EXTRAS="?sslmode=verify-full&sslrootcert=%2Fetc%2Fssl%2Fcerts%2Fca-certificates.crt"

# Simplified Celery broker configuration using Redis

If the executor type is set to *CeleryExecutor* you'll need a Celery broker. Here is a list of Redis configuration variables
and their default values. They're used to compute the `AIRFLOW__CELERY__BROKER_URL` variable for you if you don't provide
it explicitly:

| Variable          | Default value | Role                           |
|-------------------|---------------|--------------------------------|
| `REDIS_PROTO`     | `redis://`    | Protocol                       |
| `REDIS_HOST`      | `redis`       | Redis server host              |
| `REDIS_PORT`      | `6379`        | Redis server port              |
| `REDIS_PASSWORD`  | empty         | If Redis is password protected |
| `REDIS_DBNUM`     | `1`           | Database number                |

You can also use those variables to adapt your compose file to match an existing Redis instance managed elsewhere.

# Main References

https://github.com/puckel/docker-airflow

https://github.com/xnuinside/airflow_in_docker_compose

https://github.com/xnuinside/airflow_in_docker_compose/tree/master/docker_with_puckel_image

https://medium.com/@xnuinside/quick-tutorial-apache-airflow-with-3-celery-workers-in-docker-composer-9f2f3b445e4 (referred)

https://airflow.readthedocs.io/en/latest/production-deployment.html

https://airflow.readthedocs.io/en/latest/howto/set-config.html#setting-configuration-options

# Import References

https://github.com/apache/airflow/blob/master/Dockerfile

https://github.com/apache/airflow/blob/master/IMAGES.rst#production-images

https://github.com/apache/airflow/issues/8605

https://airflow.apache.org/docs/stable/configurations-ref.html
