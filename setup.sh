#!/bin/bash

at_sigint() {
  if [[ "$NODE_TYPE" == "master" ]]
  then
    su - dbadmin -c "${VERTICA_HOME}/bin/admintools -t stop_db -d docker"
  else
    while kill -0 $(pgrep -f "/opt/vertica/bin/vertica -D"); do
      sleep 1
    done
  fi
  exit 0
}

set -e

if [[ ! -d "${VERTICA_HOME}/catalog" ]] || [[ ! -d "${VERTICA_HOME}/data" ]]
then
  echo "Creating data and catalog directories..."
  chown -R dbadmin:verticadba ${VERTICA_HOME}
  su - dbadmin -c "mkdir -p ${VERTICA_HOME}/catalog -m 0755"
  su - dbadmin -c "mkdir -p ${VERTICA_HOME}/data -m 0755"
fi
echo "Data and catalog dirs exist on this node."

if [[ "$NODE_TYPE" == "master" ]]
then
  if ! rpm -q vertica
  then 
    echo "Installing RPM on this node..."
    rpm -Uvh /tmp/vertica.rpm
    chown -R dbadmin:verticadba ${VERTICA_HOME}/config
    chown -R dbadmin:verticadba ${VERTICA_HOME}/log
  fi
  echo "The RPM is installed."

  if [[ ! -e ${VERTICA_HOME}/config/admintools.conf ]]
  then
    echo "Setting up a Vertica cluster from this master node..."
    ${VERTICA_HOME}/sbin/install_vertica \
      --hosts "$CLUSTER_NODES" \
      --rpm /tmp/vertica.rpm \
      --no-system-configuration \
      --license CE \
      --accept-eula \
      --dba-user dbadmin \
      --dba-user-password-disabled \
      --failure-threshold NONE
  fi
  echo "The cluster is set up."

  if ! su - dbadmin -c "${VERTICA_HOME}/bin/admintools -t view_cluster" | grep -q docker
  then
    echo "Now creating the database..."
    su - dbadmin -c "${VERTICA_HOME}/bin/admintools \
      -t create_db \
      -s "$CLUSTER_NODES" \
      -d docker \
      -c ${VERTICA_HOME}/catalog \
      -D ${VERTICA_HOME}/data \
      --skip-fs-checks"
  fi
  echo "The docker database has been created on the cluster."

  if ! su - dbadmin -c "${VERTICA_HOME}/bin/admintools -t db_status -s UP" | grep -q docker
  then
    echo "Starting Vertica..."
    su - dbadmin -c "${VERTICA_HOME}/bin/admintools -t start_db -d docker --force --noprompts"
  fi
  echo "Vertica is started."

  if ! su - dbadmin -c "${VERTICA_HOME}/bin/vsql -qt -c 'select schema_name from schemata'" | grep -q online_sales
  then 
    echo "Importing VMart schema data in this cluster"
    su - dbadmin -c "cd /opt/vertica/examples/VMart_Schema/;./vmart_gen >/dev/null 2>&1;/opt/vertica/bin/vsql -q -f vmart_define_schema.sql;/opt/vertica/bin/vsql -q -f vmart_load_data.sql"
  fi
  echo "The VMart schema is imported."

  echo "---------------------------------------------------------------------------------------------------------------------------------------"
  echo "You can now connect to the server '$(hostname -I)' on port 5433, using the 'docker' database with the user 'dbadmin' without password."
  echo "---------------------------------------------------------------------------------------------------------------------------------------"
fi

trap at_sigint INT
while true; do
  sleep 10
done

