#!/usr/bin/env bash

set -eu -o pipefail

DOCKER_IMAGE=${DOCKER_IMAGE:-altinity/dbench:latest}
source ./sensitive-data.sh

docker login -u $DOCKER_USER
docker build -t $DOCKER_IMAGE .
docker push $DOCKER_IMAGE
