#!/bin/bash
set -e

# Start a SSH server on the node
service sshd start

# Start NTPD
service ntpd start

if [ "$1" = 'install' ]
then
    # Vertica install script
    ${VERTICA_HOME}/sbin/install_vertica \
        --hosts "$2" \
        --rpm /tmp/vertica.rpm \
        --no-system-configuration \
        --license CE \
        --accept-eula \
        --dba-user dbadmin \
        --dba-user-password-disabled \
        --failure-threshold NONE
    # Start database
    su - dbadmin -c "${VERTICA_HOME}/bin/admintools -t create_db -s $2 -d docker -c ~/catalog -D ~/data"
    echo "Vertica is now started on this node."
elif [ "$1" = 'noinstall' ]
then
    echo "This node is now ready to be added to a cluster."
else
    echo "Illegal argument: choose between 'install' and 'noinstall'"
    exit 1
fi

while true; do
    sleep 1
done
