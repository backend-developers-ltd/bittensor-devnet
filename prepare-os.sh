#!/bin/sh -eux
# Copyright 2020, Reef Technologies (reef.pl), All rights reserved.

DOCKER_BIN="$(command -v docker || true)"
DOCKER_COMPOSE_BIN="$(command -v docker-compose || true)"
JQ_BIN="$(command -v jq || true)"

if [ -x "${DOCKER_BIN}" ] && [ -x "${DOCKER_COMPOSE_BIN}" ] && [ -x "${SENTRY_CLI}" ] && [ -x "${B2_CLI}" ] && [ -x "${AWS_CLI}" ] && [ -x "${JQ_BIN}" ]; then
    echo "\e[31mEverything required is already installed!\e[0m";
    exit 0;
fi

if [ ! -x "${JQ_BIN}" ]; then
  apt-get -y install jq
fi
