# Copyright 2020 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###############################################################################################
# This file is autogenerated by the repository at https://github.com/gocd/gocd.
# Please file any issues or PRs at https://github.com/gocd/gocd
###############################################################################################

FROM alpine:latest as gocd-agent-unzip

ARG UID=1000

RUN \
  apk --no-cache upgrade && \
  apk add --no-cache curl && \
  curl --fail --location --silent --show-error "https://download.gocd.org/binaries/20.8.0-12213/generic/go-agent-20.8.0-12213.zip" > /tmp/go-agent-20.8.0-12213.zip

RUN unzip /tmp/go-agent-20.8.0-12213.zip -d /
RUN mv /go-agent-20.8.0 /go-agent && chown -R ${UID}:0 /go-agent && chmod -R g=u /go-agent

FROM centos:7

LABEL gocd.version="20.8.0" \
  description="GoCD agent based on centos version 7" \
  maintainer="ThoughtWorks, Inc. <support@thoughtworks.com>" \
  url="https://www.gocd.org" \
  gocd.full.version="20.8.0-12213" \
  gocd.git.sha="1e23a06e496205ced5f1a8e83d9b209fc0a290cb"

ADD https://github.com/krallin/tini/releases/download/v0.18.0/tini-static-amd64 /usr/local/sbin/tini

# force encoding
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8
ENV GO_JAVA_HOME="/gocd-jre"
ENV BASH_ENV="/opt/rh/sclo-git212/enable"
ENV ENV="/opt/rh/sclo-git212/enable"

ARG UID=1000
ARG GID=1000

RUN \
# add mode and permissions for files we added above
  chmod 0755 /usr/local/sbin/tini && \
  chown root:root /usr/local/sbin/tini && \
# add our user and group first to make sure their IDs get assigned consistently,
# regardless of whatever dependencies get added
# add user to root group for gocd to work on openshift
  useradd -u ${UID} -g root -d /home/go -m go && \
  yum update -y && \
  yum install --assumeyes centos-release-scl && \
  yum install --assumeyes sclo-git212 mercurial subversion openssh-clients bash unzip curl procps sysvinit-tools coreutils && \
  cp /opt/rh/sclo-git212/enable /etc/profile.d/sclo-git212.sh && \
  yum clean all && \
  curl --fail --location --silent --show-error 'https://github.com/AdoptOpenJDK/openjdk14-binaries/releases/download/jdk-14.0.2%2B12/OpenJDK14U-jre_x64_linux_hotspot_14.0.2_12.tar.gz' --output /tmp/jre.tar.gz && \
  mkdir -p /gocd-jre && \
  tar -xf /tmp/jre.tar.gz -C /gocd-jre --strip 1 && \
  rm -rf /tmp/jre.tar.gz && \
  mkdir -p /go-agent /docker-entrypoint.d /go /godata

ADD docker-entrypoint.sh /


COPY --from=gocd-agent-unzip /go-agent /go-agent
# ensure that logs are printed to console output
COPY --chown=go:root agent-bootstrapper-logback-include.xml agent-launcher-logback-include.xml agent-logback-include.xml /go-agent/config/

RUN chown -R go:root /docker-entrypoint.d /go /godata /docker-entrypoint.sh \
    && chmod -R g=u /docker-entrypoint.d /go /godata /docker-entrypoint.sh


ENTRYPOINT ["/docker-entrypoint.sh"]

USER go
