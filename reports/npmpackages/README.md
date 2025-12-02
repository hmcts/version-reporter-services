# NPM Reports Microservice
The Version Reporter Service MicroServices Project

### Container image used
https://hub.docker.com/r/alpine/k8s

### Report details

This report will query the github organisation and retrieve all package.json and package-lock.json files to extract all the NPM packages that are dependencies within the organisation.

The script uses the `readarray` command which is not included in macOS by default.

You will need to install `readarray` or an equivalent tool or run the script on Linux.
