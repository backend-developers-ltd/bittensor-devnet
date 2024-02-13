#!/bin/sh -eux
# Copyright 2020, Reef Technologies (reef.pl), All rights reserved.

DOCKER_BIN="$(command -v docker || true)"
DOCKER_COMPOSE_BIN="$(command -v docker-compose || true)"
JQ_BIN="$(command -v jq || true)"


if [ ! -x "${DOCKER_BIN}" ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    apt-get -y install docker-ce
    usermod -aG docker "$USER"
fi

if [ ! -x "${DOCKER_COMPOSE_BIN}" ]; then
    apt-get -y install docker-ce docker-compose
fi

if [ ! -x "${JQ_BIN}" ]; then
  apt-get -y install jq
fi
