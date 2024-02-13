#!/bin/sh -eux
# Copyright 2020, Reef Technologies (reef.pl), All rights reserved.

DOCKER_BUILDKIT=0 docker-compose build

# Tag the first image from multi-stage app Dockerfile to mark it as not dangling
BASE_IMAGE=$(docker images --quiet --filter="label=builder=true" | head -n1)
docker image tag "${BASE_IMAGE}" local-subtensor/app-builder

SERVICES=$(docker-compose ps --services 2>&1 > /dev/stderr \
           | grep -v -e 'is not set' -e db -e redis)

# shellcheck disable=2086
docker-compose stop $SERVICES

# start everything
docker-compose up -d

# Clean all dangling images
docker images --quiet --filter=dangling=true \
    | xargs --no-run-if-empty docker rmi \
    || true
