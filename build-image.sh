#!/bin/bash -eux

IMAGE_NAME="backenddevelopersltd/compute-horde-local-subtensor:v0-latest"
docker build --platform=linux/amd64 -t $IMAGE_NAME .
