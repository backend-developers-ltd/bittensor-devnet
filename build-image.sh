#!/bin/bash -eux

IMAGE_NAME="backenddevelopersltd/compute-horde-local-subtensor:v0-latest"
docker build -t $IMAGE_NAME .
