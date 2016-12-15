FROM mariadb:10.1
MAINTAINER Bruno Perel

ADD container.properties /home/container.properties
ADD scripts /home/scripts

RUN bash -c "chmod a+x /home/scripts/*"

RUN apt-get update && \
    apt-get install -y mariadb-client p7zip p7zip-full wget

RUN bash -c "sed -i \"s%max_allowed_packet.*%max_allowed_packet      = 128M%g\" /etc/mysql/my.cnf" && \
    bash -c "sed -i \"s%#bind-address=0.0.0.0%bind-address=0.0.0.0%g\" /etc/mysql/my.cnf"
