FROM centos:centos6.7
MAINTAINER Francois Jehl <f.jehl@criteo.com>

# Build time arguments
ARG VERTICA_RPM

# Create DBAdmin
RUN groupadd -r verticadba
RUN useradd -r -m -g verticadba dbadmin

# Environment Variables
ENV VERTICA_HOME /opt/vertica

# Yum dependencies
RUN yum install -y \
    which \
    openssh-server \
    openssh-clients \
    dialog \
    pstack \
    sysstat \
    mcelog \
    bc \
    ntp

# DBAdmin account configuration
USER dbadmin
ENV LANG "en_US.UTF-8" 
RUN echo "export TZ=/usr/share/zoneinfo/Etc/Universal" >> ~/.bash_profile
RUN mkdir ~/.ssh && cd ~/.ssh && ssh-keygen -t rsa -q -f id_rsa
RUN cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Root SSH configuration
USER root
RUN mkdir ~/.ssh && cd ~/.ssh && ssh-keygen -t rsa -q -f id_rsa
RUN cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Vertica RPM
USER root
ADD ${VERTICA_RPM} /tmp/vertica.rpm
RUN rpm -i /tmp/vertica.rpm

# Vertica specific system requirements
RUN echo "session    required    pam_limits.so" >> /etc/pam.d/su
RUN echo "dbadmin    -    nofile  65536" >> /etc/security/limits.conf
#FIXME: sends a "user cannot see its home" error.
#RUN echo "dbadmin    -    nice    0" >> /etc/security/limits.conf

# Entrypoint
COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["install","localhost"]

EXPOSE 5433
