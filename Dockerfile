FROM centos:centos7

MAINTAINER Hiroaki Sano <hiroaki.sano.9stories@gmail.com>
#ARG CACHEBUST=1

# Basic packages
RUN rpm -Uvh http://download.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
  && yum -y install passwd sudo git wget openssl openssh openssh-server openssh-clients selinux-policy jq

# Create user
RUN useradd hiroakis \
 && echo "hiroakis" | passwd hiroakis --stdin \
 && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config \
 && sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config \
 && echo "hiroakis ALL=(ALL) ALL" >> /etc/sudoers.d/hiroakis

# Redis
RUN yum install -y redis

# RabbitMQ
RUN yum install -y socat \
  && rpm -Uvh https://github.com/rabbitmq/erlang-rpm/releases/download/v20.1.7/erlang-20.1.7-1.el7.centos.x86_64.rpm \
  && rpm --import http://www.rabbitmq.com/rabbitmq-signing-key-public.asc \
  && rpm -Uvh https://dl.bintray.com/rabbitmq/all/rabbitmq-server/3.7.0/rabbitmq-server-3.7.0-1.el7.noarch.rpm \
  && git clone git://github.com/joemiller/joemiller.me-intro-to-sensu.git \
  && cd joemiller.me-intro-to-sensu/; ./ssl_certs.sh clean && ./ssl_certs.sh generate \
  && mkdir /etc/rabbitmq/ssl \
  && cp /joemiller.me-intro-to-sensu/server_cert.pem /etc/rabbitmq/ssl/cert.pem \
  && cp /joemiller.me-intro-to-sensu/server_key.pem /etc/rabbitmq/ssl/key.pem \
  && cp /joemiller.me-intro-to-sensu/testca/cacert.pem /etc/rabbitmq/ssl/
ADD ./files/rabbitmq.config /etc/rabbitmq/
RUN rabbitmq-plugins enable rabbitmq_management

# Sensu server
ADD ./files/sensu.repo /etc/yum.repos.d/
RUN yum install -y sensu
ADD ./files/config.json /etc/sensu/
RUN mkdir -p /etc/sensu/ssl \
  && cp /joemiller.me-intro-to-sensu/client_cert.pem /etc/sensu/ssl/cert.pem \
  && cp /joemiller.me-intro-to-sensu/client_key.pem /etc/sensu/ssl/key.pem

# uchiwa
RUN yum install -y uchiwa
ADD ./files/uchiwa.json /etc/sensu/

# supervisord
#RUN wget http://peak.telecommunity.com/dist/ez_setup.py;python ez_setup.py \
#  && easy_install supervisor
RUN wget https://bootstrap.pypa.io/get-pip.py && python get-pip.py \ 
  && pip install supervisor

ADD files/supervisord.conf /etc/supervisord.conf
# Without this rabbitmq doesn't work
RUN setenforce 0 || echo Selinux disabled

# this gives an error
#RUN chcon 'system_u:object_r:rabbitmq_exec_t:s0' /usr/lib64/erlang/erts*/bin/beam* && \
#  chcon 'system_u:object_r:rabbitmq_exec_t:s0' /usr/lib64/erlang/erts*/bin/epmd

RUN /usr/sbin/sshd-keygen

EXPOSE 22 3000 4567 5671 15672

CMD ["/usr/bin/supervisord"]

