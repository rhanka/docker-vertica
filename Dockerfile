FROM centos:centos7
MAINTAINER Francois Jehl <francoisjehl@gmail.com>
ARG proxy

# Environment Variables
ENV http_proxy $proxy
ENV https_proxy $proxy
ENV VERTICA_HOME=/opt/vertica \
    WITH_VMART=false \
    NODE_TYPE=master \
    CLUSTER_NODES=localhost \
    GDBSERVER_PORT=2159
ARG ENABLE_GDB_DEBUG=true

ENV http_proxy $proxy
ENV https_proxy $proxy

RUN localedef -i en_US -f UTF-8 en_US.UTF-8

# Yum dependencies
RUN yum install -y \
    which \
    openssh-server \
    openssh-clients \
    openssl \
    iproute \
    dialog \
    gdb \
    gdb-gdbserver \
    sysstat \
    mcelog \
    bc \
    ntp \
    gcc-c++ \
    cmake \
    python-setuptools

# Debug infos for GDB
RUN if [ ${ENABLE_GDB_DEBUG} = 'true' ]; then debuginfo-install -y \
    expat \
    glibc \
    keyutils-libs \
    libcom_err \
    libgcc \
    libstdc++ \
    zlib \
    ; fi

# Install supervisor
RUN easy_install supervisor

# DBAdmin account configuration
RUN groupadd -r verticadba \
    && useradd -r -m -g verticadba dbadmin

USER dbadmin
RUN echo "export LANG=en_US.UTF-8" >> ~/.bash_profile \
    && echo "export TZ=/usr/share/zoneinfo/Etc/Universal" >> ~/.bash_profile \
    && mkdir ~/.ssh && cd ~/.ssh && ssh-keygen -t rsa -q -f id_rsa \
    && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Root SSH configuration
USER root
RUN mkdir ~/.ssh && cd ~/.ssh && ssh-keygen -t rsa -q -f id_rsa \
    && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys \
    && /usr/bin/ssh-keygen -A

# Vertica specific system requirements
RUN echo "session    required    pam_limits.so" >> /etc/pam.d/su \
    && echo "dbadmin    -    nofile  65536" >> /etc/security/limits.conf \
    && echo "dbadmin    -    nice  0" >> /etc/security/limits.conf

#SupervisorD configuration
COPY sshd.sv.conf ntpd.sv.conf verticad.sv.conf gdbserverd.sv.conf /etc/supervisor/conf.d/
COPY supervisord.conf /etc/supervisord.conf

# Vertica and GDB daemon-like startup scripts
COPY verticad /usr/local/bin/verticad
COPY gdbserverd /usr/local/bin/gdbserverd

EXPOSE 5433
EXPOSE ${GDBSERVER_PORT}
#Starting supervisor
CMD ["/usr/bin/supervisord", "-n"]
