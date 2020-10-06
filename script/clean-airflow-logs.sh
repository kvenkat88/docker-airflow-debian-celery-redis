#!/bin/bash

set -e

# AIRFLOW_HOME home valus is not provided, it takes default value mentioned else take custom value provided
DIRECTORY=${AIRFLOW_HOME:-/usr/local/airflow}
RETENTION=${AIRFLOW__WORKER_LOG_RETENTION_DAYS:-15}

# On Unix-like operating systems, the trap command is a function of the shell that responds to hardware signals and other events.
# trap defines and activates handlers to be run when the shell receives signals or other special conditions.
trap "exit" INT TERM

EVERY=$((15*60))

echo "Cleaning logs every $EVERY seconds"

while true; do
  seconds=$(( $(date -u +%s) % EVERY))
  echo "Seconds calculated is $seconds"
  [[ $seconds -lt 1 ]] || sleep $((EVERY - seconds))

  echo "Trimming airflow logs to ${RETENTION} days."
  find "${DIRECTORY}"/logs -mtime +"${RETENTION}" -name '*.log' -delete
done