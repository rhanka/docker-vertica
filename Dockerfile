FROM centos:centos7.2.1511
MAINTAINER Francois Jehl <f.jehl@criteo.com>

# Environment Variables
ENV VERTICA_HOME /opt/vertica
ENV NODE_TYPE master
ENV CLUSTER_NODES localhost
RUN localedef --quiet -c -i en_US -f UTF-8 en_US.UTF-8

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
RUN groupadd -r verticadba
RUN useradd -r -m -g verticadba dbadmin
USER dbadmin
RUN echo "export LANG=en_US.UTF-8" >> ~/.bash_profile
RUN echo "export TZ=/usr/share/zoneinfo/Etc/Universal" >> ~/.bash_profile
RUN mkdir ~/.ssh && cd ~/.ssh && ssh-keygen -t rsa -q -f id_rsa
RUN cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Root SSH configuration
USER root
RUN mkdir ~/.ssh && cd ~/.ssh && ssh-keygen -t rsa -q -f id_rsa
RUN cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
RUN /usr/bin/ssh-keygen -A

# Vertica specific system requirements
RUN echo "session    required    pam_limits.so" >> /etc/pam.d/su
RUN echo "dbadmin    -    nofile  65536" >> /etc/security/limits.conf
RUN echo "dbadmin    -    nice  0" >> /etc/security/limits.conf

#SupervisorD configuration
COPY sshd.sv.conf /etc/supervisor/conf.d/
COPY ntpd.sv.conf /etc/supervisor/conf.d/
COPY verticad.sv.conf /etc/supervisor/conf.d/
COPY supervisord.conf /etc/supervisord.conf

# Vertica daemon-like startup script
COPY verticad /usr/local/bin/verticad

#Starting supervisor
CMD ["/usr/bin/supervisord", "-n"]
