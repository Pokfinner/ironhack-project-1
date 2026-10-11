#!/bin/bash
# Build and push all Docker images to DockerHub
# Usage: ./build.sh [version]   e.g. ./build.sh v2   (default: v1)

set -e

DOCKERHUB_USER="hserindik"
VERSION="${1:-v1}"

for APP in worker vote result; do
  echo "=== Building $APP ($VERSION) ==="
  docker build -t $DOCKERHUB_USER/$APP:latest -t $DOCKERHUB_USER/$APP:$VERSION ./$APP

  echo "=== Pushing $APP ==="
  docker push $DOCKERHUB_USER/$APP --all-tags
done

echo "Done! All images pushed with tags: latest, $VERSION"
