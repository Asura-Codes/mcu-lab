#!/usr/bin/env bash
TAG=${1:-asuracodes/mcu-lab:local}
echo "Building base image as $TAG (this may take a long time)..."
docker build --progress=plain -f .devcontainer/Dockerfile -t "$TAG" ..
rc=$?
if [ $rc -eq 0 ]; then
  echo "Build succeeded. Reopen the workspace in container to use $TAG."
else
  echo "Build failed (exit code $rc)." >&2
fi
exit $rc
