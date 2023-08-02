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

if [[ "$PUBLISH_IMAGE" == "$REPORT_NAME" || "$PUBLISH_IMAGE" == "All" ]]
then
  echo "Publishing a new image to '${ACR_NAME} for '${REPORT_NAME}'"
  az acr build -r "${ACR_NAME}" -t "${TAG}" -g "${ACR_RESOURCE_GROUP}" .
else
  echo "No image published to '${ACR_NAME}' for ${REPORT_NAME}."
  echo "You can manually publish your image via the pipeline 'Publish New Image' option"
fi
