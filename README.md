# What is Version Reporter

## Overview

The Version Reporter Service MicroServices Project is a scaffold that allows custom reporting services to be built easily via the same pipeline and repository whilst maintaining any custom configuration required within the report itself.

### Goal

Provide a single solution to allow reporting of unique or custom services within the project.
<br> Make it easy to add new reports in future by making the scaffolding in this repository generic and easy to scale.

### Report structure

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

### Build and Publish

Container images are built via the ADO pipeline, the final step of the pipeline is a bash script will accept inputs and runs the Azure CLI `acr build` command to build and push the newly built image to Azure Container Registry.

There is a variable defined during the script which defines the tag used for the container image, this is made up of easily determined information

```yaml
  - script: |
      repo_sha=$(git rev-parse --verify HEAD)
      image_tag_sha=${repo_sha:0:7}
      last_commit_time=$(date +'%Y%m%d%H%M%S')
      image_tag=$(echo ${image_tag_sha}-${last_commit_time})
      
      echo "##vso[task.setvariable variable=tag]${{variables.acrRepository}}/${{report.name}}:prod-${image_tag}"
    displayName: "ACR: Tag ${{report.name}}"
```

This variable as well as other variables and parameters defined in the pipeline are then used during the build and publish script.
The arguments are position sensitive for the bash script but these should not need to change when adding a new report.

```yaml
  - task: AzureCLI@1
    displayName: 'ACR: Build ${{report.name}}'
    enabled: true
    inputs:
      azureSubscription: ${{ variables.acrServiceConnection }}
      workingDirectory: $(System.DefaultWorkingDirectory)/reports/${{report.name}}
      scriptType: bash
      scriptPath: $(System.DefaultWorkingDirectory)/pipeline-scripts/publish-image.sh
      arguments: ${{report.name}} $(tag) ${{variables.acrResourceGroup}} ${{variables.acrName}}
```

### Adding new reports to the pipeline

Adding a new report to the pipeline is the final step to make it all work. 

When you have created the report files, scripts and structure defined under [Report structure](#report-structure) you will need to add the report into the pipeline so that you can build and publish the image.

The pipeline steps/jobs are fixed and there is no need to modify these to add a new report. Within the pipeline there is a parameter called `reports` which is a `dictionary` of reports and the scripting language e.g. `helmcharts` and `bash`, this means the scripts within the `helmcharts` report have been written in `bash`.

Add your new report to this list where `name` should match the folder name of your report and `type` should be the scripting language used for the script. The language will determine the template used to prepare and build the script if necessary.

## Deployment

Deployment of the reports is carried out via Flux which is not part of this repository.

More information can be found [here](https://github.com/hmcts/sds-flux-config/tree/9a8ac5f9d043b4a95b9a05e6ed47c28e0c59c563/apps/monitoring/version-reporter).

The images created by in this repository should be used for the deployments along with any necessary inputs for them to operate correctly.

## Local Development

The repository is split into pipeline development and reports development:

- components - the Terraform code that builds the required resources for the reporting services. See [Infrastructure](#infrastructure) for more info.
- pipeline-reports-templates - examples of nodejs and python report folders that can be copied and customised into the `reports` folder, see [Report structure](#report-structure) for more info.
- pipeline-scripts - scripts used within the pipeline to carry out specific tasks
- pipeline-templates - these are ADO templates that are loaded by the pipeline as/when required
- reports - the actual code for each report type

Pipeline development is utilising ADO Yaml and development requires testing to take place via Azure DevOps where you can test pipeline changes from your branch.

The following are useful tools or references for ADO pipeline development:

- [ADO YAML Reference](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/?view=azure-pipelines)
- [VSCode pipeline extension](https://marketplace.visualstudio.com/items?itemName=ms-azure-devops.azure-pipelines)

Its also possible to edit the pipeline within Azure DevOps which provides live linting, references to existing tasks and the ability to validate and download the complete YAML file at the end to be stored in Git: [Link](https://learn.microsoft.com/en-us/azure/devops/pipelines/get-started/yaml-pipeline-editor?view=azure-devops)

Report development is dependant on updating existing or creating new reports.
Each of the existing reports is written in a specific language which we've discussed already, this means you will need to setup your local environment to suit if you are editing one of these reports:

- NodeJS - to setup NodeJS it is recommended to install `NVM`/`FNM` (OS dependant options) which are simple tools to help manage multiple NodeJS installs:
  - [MacOSX](https://nodejs.org/en/download/package-manager)
  - [Windows](https://nodejs.org/en/download/package-manager)

- Python - to setup Python it is recommended to install `Pyenv` which allows you to manage multiple Python versions and virtual environments
  - [MacOSX](https://realpython.com/intro-to-pyenv/#installing-pyenv)
  - [Windows](https://github.com/pyenv-win/pyenv-win)

If you are creating a new report, please try to use one of the current language so we do not end up with too many languages that cannot be maintained by the team. NodeJS, Python and Bash are the preferred options as they are widely known or documented.

### Helper Scripts

Each of the reports has access to a Managed Identity in AKS to authenticate to Azure.

This happens automatically within AKS as the monitoring namespace used for deployment is setup to provide Managed Identity credentials to the deployments within it as environment variables.

The Managed Identity is also used to lookup secrets from Key Vault and provide them as a volume mount in the pod. 
<br>Within this volume there will be a file per secret referenced in the [Flux configuration](https://github.com/hmcts/cnp-flux-config/blob/master/apps/monitoring/version-reporter/renovate/renovate.yaml#L38). These files contain the secret values and for the reports to use them we have created a helper scripts that are built into each container image.

- [entrypoint.sh](./reports/aksversions/entrypoint.sh) - this is a very simple script that allows you to call multiple other scripts, of any language even though the script itself is bash, in a specific order. This means we can setup the environment before running the main reporting script.
- [set_env.sh](./reports/aksversions/set_env.sh) - this script sets up environment variables for the main script. It is run first as part of `entrypoint.sh` and scans the supplied directory for files then uses the file names and contents to create environment variables.

#### entrypoint.sh

This is a very simple script, it has no logic or inputs and is only used to make it easier to trigger scripts in a specific order and keep the dockerfile simple to use and read

```dockerfile
CMD ["/app/entrypoint.sh"]
```

#### set_env.sh

The set_env script requires 2 inputs which can be supplied as environment variables to the docker image. This means it can be used during local development/testing and in Flux for deployment.

The following code snippet shows the inputs required to customise the path that the script will scan:

```bash
# Get the vault name from the environment variable
secret_path=${SECRET_PATH:-/mnt/secrets}
vault_name=${VAULT_NAME:-vault}

# Construct the directory path
directory_path="$secret_path/$vault_name"
```

Every file within this path will have an equivalent environment variable created and the filename is used as the variable name e.g. 

    File name = TOKEN
    File content = MySecretTokenValue

    Environment variable created: `TOKEN=MySecretTokenValue`
