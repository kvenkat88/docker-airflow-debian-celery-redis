ARG PYTHON_BASE_IMAGE="python:3.8-slim-buster"
FROM ${PYTHON_BASE_IMAGE}

ARG PYTHON_BASE_IMAGE="python:3.8-slim-buster"
ENV PYTHON_BASE_IMAGE=${PYTHON_BASE_IMAGE}

MAINTAINER HPS Cloud Services
LABEL maintainer="HPS Cloud Services"

# References for Dockerfile creation
# https://netflixtechblog.com/scheduling-notebooks-348e6c14cfd6
# https://medium.com/@tomaszdudek/yet-another-scalable-apache-airflow-with-docker-example-setup-84775af5c451

# Important One
# https://github.com/puckel/docker-airflow
# https://github.com/xnuinside/airflow_in_docker_compose/tree/master/docker_with_puckel_image
# https://medium.com/@xnuinside/quick-tutorial-apache-airflow-with-3-celery-workers-in-docker-composer-9f2f3b445e4 (referred)
# https://github.com/jghoman/awesome-apache-airflow
# https://airflow.readthedocs.io/en/latest/production-deployment.html

# Never prompt the user for choices on installation/configuration of packages
# If you want to use console programs that create text-based user interfaces (e.g. clear, less, top, vim, nano, …)
# the TERM environment variable (↑) must be set.
ENV DEBIAN_FRONTEND=noninteractive TERM=linux LANGUAGE=C.UTF-8 LANG=C.UTF-8 LC_ALL=C.UTF-8 LC_CTYPE=C.UTF-8 LC_MESSAGES=C.UTF-8

# Airflow
ARG AIRFLOW_VERSION=1.10.12
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

ARG AIRFLOW_USER="airflow"
ARG AIRFLOW_GROUP="airflow"
ARG uid=2000
ARG gid=200
ENV AIRFLOW_USER=${AIRFLOW_USER}
ENV AIRFLOW_GROUP=${AIRFLOW_GROUP}

# Disable noisy "Handling signal" log messages:
# ENV GUNICORN_CMD_ARGS --log-level WARNING

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        ca-certificates \
        bash \
        less \
        ldap-utils \
        krb5-user \
        net-tools \
        lsb-release \
        curl \
        rsync \
        netcat \
        dumb-init \
        locales \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && groupadd -g ${gid} ${AIRFLOW_GROUP} \
    && useradd -u ${uid} -g ${AIRFLOW_GROUP} -ms /bin/bash -d ${AIRFLOW_USER_HOME} ${AIRFLOW_USER} \
    && pip install --no-cache-dir -U pip setuptools wheel \
    && pip install --no-cache-dir pytz \
    && pip install --no-cache-dir pyOpenSSL \
    && pip install --no-cache-dir ndg-httpsclient \
    && pip install --no-cache-dir Jinja2 \
    && pip install --no-cache-dir cryptography \
    && pip install --no-cache-dir flask-bcrypt \
    && pip install --no-cache-dir pyasn1 \
    && pip install --no-cache-dir apache-airflow[crypto,celery,postgres,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install --no-cache-dir redis \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install --no-cache-dir ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

# Switch to AIRFLOW_HOME
WORKDIR ${AIRFLOW_HOME}

# Copy entrypoint to path
COPY script/entrypoint.sh ${AIRFLOW_HOME}/entrypoint.sh

# Copy airflow.cfg from local to conatiner path
COPY config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg

# Copy "cron" scripts for clean logs. By default 15 days of log would be retained and we can customize too.
COPY script/clean-airflow-logs.sh ${AIRFLOW_HOME}/clean-airflow-logs.sh

# Create logs directory so we can own it when we mount volumes
RUN mkdir -p ${AIRFLOW_HOME}/logs \
    && chown -R ${AIRFLOW_USER}:${AIRFLOW_GROUP} ${AIRFLOW_HOME} \
    && pwd \
    && ls -ltr ${AIRFLOW_HOME} \
    && chmod +x ./entrypoint.sh \
    && chmod +x ./clean-airflow-logs.sh

# Expose all airflow ports
EXPOSE 8080 5555 8793

# Run airflow with minimal init
ENTRYPOINT ["/usr/bin/dumb-init", "--", "./entrypoint.sh"]

# Invoke the airflow to start the webserver in background
CMD ["webserver"]

