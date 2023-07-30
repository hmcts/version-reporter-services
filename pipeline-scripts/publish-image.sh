#!/bin/bash

#--------------------------------------------------------------------------------------
# Determine what changes have been merged, filter on current report, count how many lines
# and remove any space using xargs. If result is not empty i.e zero (0) then some
# changes have been merged in and we publish a new image
#--------------------------------------------------------------------------------------

REPORT_NAME=$1
TAG=$2
ACR_RESOURCE_GROUP=$3
ACR_NAME=$4

CHANGES=$(git diff HEAD^..HEAD --name-only | grep -c "/${REPORT_NAME}/" | xargs)
if [[ "$CHANGES" -gt 0 ]]
then
  echo "${CHANGES} files have been modified in '${REPORT_NAME}' report. Publishing a new image to '${ACR_NAME}"
  az acr build -r "$ACR_NAME" -t "$TAG" -g "$ACR_RESOURCE_GROUP" .
else
  echo "${CHANGES} files have been modified in '${REPORT_NAME}' report. No image published to '${ACR_NAME}'"
fi
