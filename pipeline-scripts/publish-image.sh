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
PUBLISH_IMAGE=$5

CHANGES=$(git diff refs/heads/master..HEAD^ --name-only | grep -c "/${REPORT_NAME}/" | xargs)

if [[ "$CHANGES" -gt 0 || "$PUBLISH_IMAGE" == "$REPORT_NAME" || "$PUBLISH_IMAGE" == "All" ]]
then

  if [[ "$PUBLISH_IMAGE" == "$REPORT_NAME" || "$PUBLISH_IMAGE" == "All" ]]
  then
    echo "Publishing a new image to '${ACR_NAME} for '${REPORT_NAME}'"
  else
    echo "${CHANGES} files have been modified in '${REPORT_NAME}' report. Publishing a new image to '${ACR_NAME}"
  fi

  az acr build -r "${ACR_NAME}" -t "${TAG}" -g "${ACR_RESOURCE_GROUP}" .
else
  echo "${CHANGES} files have been modified in '${REPORT_NAME}' report. No image published to '${ACR_NAME}'"
fi
