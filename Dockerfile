# Copyright 2022 ThoughtWorks, Inc.
# Build This Image on Centos 7 base OS, building image on Mac may cause issues running image in container.
#

FROM curlimages/curl:latest as gocd-agent-unzip
USER root
ARG UID=1000
RUN curl --fail --location --silent --show-error "https://download.gocd.org/binaries/22.1.0-13913/generic/go-agent-22.1.0-13913.zip" > /tmp/go-agent-22.1.0-13913.zip
RUN unzip /tmp/go-agent-22.1.0-13913.zip -d /
RUN mv /go-agent-22.1.0 /go-agent && chown -R ${UID}:0 /go-agent && chmod -R g=u /go-agent

FROM docker.io/centos:7

LABEL gocd.version="22.1.0" \
  description="GoCD agent based on docker.io/centos:7" \
  maintainer="ThoughtWorks, Inc. <support@thoughtworks.com>" \
  url="https://www.gocd.org" \
  gocd.full.version="22.1.0-13913" \
  gocd.git.sha="f4c9c1650e2e27fe0a9962faa39536f94f57e297"

ADD https://github.com/krallin/tini/releases/download/v0.19.0/tini-static-amd64 /usr/local/sbin/tini

# force encoding
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
ENV GO_JAVA_HOME="/gocd-jre"
ENV BASH_ENV="/opt/rh/rh-git218/enable"
ENV ENV="/opt/rh/rh-git218/enable"

ARG UID=1000
ARG GID=1000

RUN \
  # add mode and permissions for files we added above
  chmod 0755 /usr/local/sbin/tini && \
  chown root:root /usr/local/sbin/tini && \
  # Below Command will reset root password for Access Shell as ROOT User
  echo "toor@123" | passwd --stdin root && \
  # add our user and group first to make sure their IDs get assigned consistently,
  # regardless of whatever dependencies get added
  # add user to root group for gocd to work on openshift
  useradd -u ${UID} -g root -d /home/go -m go && \
  yum install --assumeyes centos-release-scl-rh && \
  yum update -y && \
  yum install -y python3 python3-pip && \
  yum install --assumeyes rh-git218 mercurial subversion openssh-clients bash unzip curl procps sysvinit-tools coreutils && \
  # cp /opt/rh/rh-git218/enable /etc/profile.d/rh-git218.sh && \
  yum clean all && \
  curl --fail --location --silent --show-error 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.2%2B8/OpenJDK17U-jre_x64_linux_hotspot_17.0.2_8.tar.gz' --output /tmp/jre.tar.gz && \
  mkdir -p /gocd-jre && \
  tar -xf /tmp/jre.tar.gz -C /gocd-jre --strip 1 && \
  rm -rf /tmp/jre.tar.gz && \
  mkdir -p /go-agent /docker-entrypoint.d /go /godata && \
  pip3 install -U pip && \
  pip3 install oci oci-cli && \
  pip3 install uuid datetime && \
  curl --url https://releases.hashicorp.com/terraform/1.2.5/terraform_1.2.5_linux_amd64.zip --output /opt/terraform_1.2.5_linux_amd64.zip && \
  unzip /opt/terraform_1.2.5_linux_amd64.zip -d /bin/ && \
  curl --url https://releases.hashicorp.com/packer/1.8.2/packer_1.8.2_linux_amd64.zip -o /opt/packer_1.8.2_linux_amd64.zip && \
  unzip /opt/packer_1.8.2_linux_amd64.zip -d /opt/ && \
  pip3 install oci oci-cli && \
  pip3 install uuid datetime && \
  yum -y install epel-release && \
  yum update -y && \
  yum install -y ansible 


ADD docker-entrypoint.sh /

# Some Usefull Information
# python: /usr/bin/python /usr/bin/python2.7 /usr/bin/python3.6 /usr/bin/python3.6m /usr/lib/python2.7 /usr/lib/python3.6 /usr/lib64/python2.7 /usr/lib64/python3.6 /etc/python /usr/local/lib/python3.6 /usr/include/python2.7 /usr/include/python3.6m

COPY --from=gocd-agent-unzip /go-agent /go-agent
# ensure that logs are printed to console output
COPY --chown=go:root agent-bootstrapper-logback-include.xml agent-launcher-logback-include.xml agent-logback-include.xml /go-agent/config/

RUN chown -R go:root /docker-entrypoint.d /go /godata /docker-entrypoint.sh \
  && chmod -R g=u /docker-entrypoint.d /go /godata /docker-entrypoint.sh


ENTRYPOINT ["/docker-entrypoint.sh"]

USER go
