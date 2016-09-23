FROM centos:7.2.1511 
MAINTAINER Francois Jehl <f.jehl@criteo.com>

# Build time arguments
ARG VERTICA_RPM

# Create DBAdmin
RUN groupadd -r verticadba
RUN useradd -r -m -g verticadba dbadmin

# Environment Variables
ENV VERTICA_HOME /opt/vertica
ENV NODE_TYPE master
ENV CLUSTER_NODES localhost
ENV OUTPUT_VERTICA_LOG false 

# Yum dependencies
RUN yum install -y \
    which \
    openssh-server \
    openssh-clients \
    openssl \
    iproute \
    dialog \
    gdb \
    sysstat \
    mcelog \
    bc \
    ntp \
    python-setuptools

RUN easy_install supervisor

# DBAdmin account configuration
USER dbadmin
RUN echo "export LANG=en_US.UTF-8" >> ~/.bash_profile
RUN echo "export TZ=/usr/share/zoneinfo/Etc/Universal" >> ~/.bash_profile

RUN mkdir ~/.ssh && cd ~/.ssh && ssh-keygen -t rsa -q -f id_rsa
RUN cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Root SSH configuration
USER root
RUN mkdir ~/.ssh && cd ~/.ssh && ssh-keygen -t rsa -q -f id_rsa
RUN cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Vertica RPM
USER root
COPY ${VERTICA_RPM} /tmp/vertica.rpm
RUN rpm -i /tmp/vertica.rpm

# Vertica data dir
RUN mkdir ${VERTICA_HOME}/data
RUN chown dbadmin:verticadba ${VERTICA_HOME}/data
RUN chmod 755 ${VERTICA_HOME}/data

# Vertica catalog dir
RUN mkdir ${VERTICA_HOME}/catalog
RUN chown dbadmin:verticadba ${VERTICA_HOME}/catalog
RUN chmod 755 ${VERTICA_HOME}/catalog

# Vertica specific system requirements
RUN echo "session    required    pam_limits.so" >> /etc/pam.d/su
RUN echo "dbadmin    -    nofile  65536" >> /etc/security/limits.conf
RUN echo "dbadmin    -    nice  0" >> /etc/security/limits.conf

#SupervisorD configuration
COPY supervisord.conf /etc/supervisord.conf
COPY verticad /usr/local/bin/verticad

# SSH key generation (handled usually by sshd initd script)
RUN /usr/bin/ssh-keygen -A

#Starting supervisor
CMD ["/usr/bin/supervisord", "-n"]
