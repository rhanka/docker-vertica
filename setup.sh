#!/bin/bash

set -e

if [[ ! -e ${VERTICA_HOME}/catalog/docker/ ]]
then
  echo "Creating data and catalog directories..."
  chown -R dbadmin:verticadba ${VERTICA_HOME}
  su - dbadmin -c "mkdir -p ${VERTICA_HOME}/catalog -m 0755"
  su - dbadmin -c "mkdir -p ${VERTICA_HOME}/data -m 0755"
  echo "Data and catalog directories created"

  if [[ "$NODE_TYPE" == "master" ]]
  then
    echo "Installing RPM on this node..."
    rpm -i /tmp/vertica.rpm
    echo "RPM installed"

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
    echo "Cluster is now set up"

    echo "Now creating the database..."
    su - dbadmin -c "${VERTICA_HOME}/bin/admintools \
      -t create_db \
      -s "$CLUSTER_NODES" \
      -d docker \
      -c ${VERTICA_HOME}/catalog \
      -D ${VERTICA_HOME}/data \
      --skip-fs-checks"
    echo "Database created on the cluster"

    echo "Finally putting some data in it"
    su - dbadmin -c "cd /opt/vertica/examples/VMart_Schema/;./vmart_gen >/dev/null 2>&1;/opt/vertica/bin/vsql -q -f vmart_define_schema.sql;/opt/vertica/bin/vsql -q -f vmart_load_data.sql"
    echo "Data imported successfully!"

  fi
elif [[ ! -d $dir ]]; then
    echo "Database is already setup on this node"
fi

if [[ "$NODE_TYPE" == "master" ]]
then
  echo "Starting Vertica..."
  su - dbadmin -c "${VERTICA_HOME}/bin/admintools -t start_db -d docker --noprompts"
  echo "---------------------------------------------------------------------------------------------------------------------------------------"
  echo "You can now connect to the server '$(hostname -I)' on port 5433, using the 'docker' database with the user 'dbadmin' without password."
  echo "---------------------------------------------------------------------------------------------------------------------------------------"
fi
