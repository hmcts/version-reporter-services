# What is Version Reporter

## Overview

The Version Reporter Service MicroServices Project is a scaffold that allows custom reporting services to be built easily via the same pipeline and repository whilst maintaining any custom configuration required within the report itself.

### Reports

Each report is a set of files specific to that report and the folder structure of this repository is designed to maintain a completely exclusive setup for each report.

Reports can be Python, Bash, NodeJS, PowerShell, or any other language that can be run within a container image.<br>
However its important to note that not all languages are currently accounted for so if you choose to use a new language then modifications are required to the pipeline code and templates.

A report should consist of:

- A Dockerfile that builds the container image that we can deploy to AKS
- A readme to detail the how and why of the report
- Ignore files e.g. .gitignore and .dockerignore
- Scripts that do the reporting work e.g. a Python script that gathers information and stores it in CosmosDB.
- Supporting files e.g. requirements.txt for Python, packages.json for NodeJS etc.
- Tests that can be run before building the container image.

### Architecture

<details>
  <summary>VRS Proposed Plan</summary>
  <img alt="VRS" src="./images/version-reporter-v2.jpg" width="80%">
</details>

### Goal

Provide a single solution to allow reporting of unique or custom services within the project.

Make it easy to add new reports in future by making the scaffolding in this repository generic and easy to scale.

## Infrastructure

The `components` folder contains the Infrastructure as Code element for version reporter.

Whilst most of the reporting work is carried out via the pre-built container images deployed to AKS, there is a need for:

- data storage - CosmosDB
- secret storage - Key Vault
- secure access - Managed Id

Terraform is being used as the deployment tool for the IaC. The folder structure is inline with HMCTS best practice and guidelines and will be familiar to other HMCTS repositories.

The code deploys the necessary resources to Azure and there are minimal changes required to add a new report.

The following variable is the only change necessary to add a new port

```hcl
/*
 * Define your partition and partition key based on your reports need
 * partition name should be the same as the report name
 * partition key should be based on the shape of the data stored
*/
variable "containers_partitions" {
  type        = map(any)
  description = "Partition Keys for corresponding database containers."
  default = {
    paloalto     = "/resourceType"
    helmcharts   = "/namespace"
    renovate     = "/repository"
    docsoutdated = "/docTitle"
    netflow      = "/netflow"
  }
}
```

If you wish to create a new report that utilises CosmosDB for storage you will need to create a new partition key in the above variable.
Each `key:value` is created in a `for_each` within the code which results in individual containers per report.

## CI/CD

This repository contains an Azure Pipeline yaml definition [file](azure-pipelines.yaml) which is used to:

- Deploy the Infrastruture as Code resources
  - CosmosDB, Key Vault, Managed Ids etc.
- Setup the build environment or prebuild the report code where necessary
  - Running Python tests
  - Install Yarn packages
- Build and publish container images to Azure Container Registry

The pipeline is deployed to [Azure DevOps](https://dev.azure.com/hmcts/PlatformOperations/_build?definitionId=812&_a=summary) where it will run on merges to master automatically.

There are 3 stages within the pipeline:

- **Precheck**
  - Installs Terraform
  - Retrieves Key Vault secrets
  - Retrieves GitHub Token
  - Runs tests
  - Sets variables
- **IaC**
  - Plans and/or Applies Terraform code to deploy the IaC resources
- **build and publish container images**
  - Creates a job per report that sets up the environment for each report depending on the technology used e.g. Bash, Node, Python
  - Builds and publishes container images to ACR using Dockerfiles

## Reports

This repository contains the code and builds for many reporting services, you will find a list below linking to the individual report readme.
If you plan to add a new report please ensure that it includes a readme with usage and build instructions.

- Docs Outdated: [Readme](reports/docsoutdated/README.md)
- Helm Charts: [Readme](reports/helmcharts/README.md)
- Hourly Usage: [Readme](reports/hourlyusage/README.md)
- Palo Alto: [Readme](reports/paloalto/README.md)
- Renovate: [Readme](reports/renovate/README.md)

## Container Images

Each of the reports contains a `Dockerfile`, this is used to build the container image that is then used for deployment to AKS.

Each `Dockerfile` is unique to the report and sets up a specific environment for that report to function such as environment variables, packages and run commands.

Example:

The `docsoutdated` report is built with Python, the container image:

- Uses a python base image
- Installs the required packages via Pip and the [requirements.txt](reports/docsoutdated/requirements.txt) file.
- Sets environment variables for access to CosmosDB
- Sets the CMD to run the [main.py](reports/docsoutdated/main.py) file that does the bulk of the work.

This image is perfectly setup to run this one report and the image when built can be deployed to AKS via Flux.

**Every report created in this repository must follow this pattern, a Dockerfile must exist and it must be capable of running the report in isolation i.e. the container image has everything required for the script(s) to run as expected.**

### Build

### Publish

## Deployment

Deployment of the reports is carried out via Flux which is not part of this repository.

More information can be found [here](https://github.com/hmcts/sds-flux-config/tree/9a8ac5f9d043b4a95b9a05e6ed47c28e0c59c563/apps/monitoring/version-reporter).

The images created by in this repository should be used for the deployments along with any necessary inputs for them to operate correctly.
