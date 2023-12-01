FROM centos:7

#COPY postgresql.conf /etc/postgresql/15/main/postgresql.conf
#COPY pg_hba.conf /etc/postgresql/15/main/pg_hba.conf
COPY repmgr.conf /
COPY postgresql.conf /
COPY pg_hba.conf /



EXPOSE 5432

RUN yum install -y epel-release maven wget
RUN yum clean all
RUN yum install -y  https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
RUN yum install -y postgresql15-server postgresql15-contrib
RUN yum install repmgr_15.x86_64 -y
RUN yum install bind-utils -y
RUN chown postgres /repmgr.conf
RUN chgrp postgres /repmgr.conf
RUN chown postgres /postgresql.conf
RUN chgrp postgres /postgresql.conf
RUN chown postgres /pg_hba.conf
RUN chgrp postgres /pg_hba.conf
RUN chmod 777 /repmgr.conf


ENV POD_NAME=podName
ENV NODE_ID=1
ENV NODE_NAME=primary
ENV PEER_POD_IP=podIP
ENV PRIMARY_POD_IP=0.0.0.0

COPY custom-entrypoint-1.sh /usr/local/bin/custom-entrypoint-1.sh

RUN chmod +x /usr/local/bin/custom-entrypoint-1.sh
ENTRYPOINT ["custom-entrypoint-1.sh"]
CMD ["postgres"]
