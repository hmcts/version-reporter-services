import asyncio
import json
import os
import pathlib
import shutil
import time
import uuid
from pathlib import Path

from azure.cosmos import exceptions
from azure.cosmos.aio import CosmosClient
from azure.identity import DefaultAzureCredential
from git import Repo
from humanfriendly import format_timespan

MAX_BATCH_SIZE = 500
DB_URL = os.environ.get("COSMOS_DB_URI", None)
DATABASE_NAME = os.environ.get("COSMOS_DB_NAME", "reports")
KEY = os.environ.get("COSMOS_KEY")
CONTAINER_NAME = os.environ.get("COSMOS_DB_CONTAINER", "cveinfo")


# Utility used to cherry pick cve object
def extract_cve_data(cve_data):
    data = dict()
    data['id'] = f'{uuid.uuid4()}'
    data['cveId'] = cve_data.get('cveMetadata').get('cveId')
    data['dataType'] = cve_data.get('dataType')
    data['dataVersion'] = cve_data.get('dataVersion')
    data['assignerShortName'] = cve_data.get('cveMetadata').get('assignerShortName')
    data['datePublished'] = cve_data.get('cveMetadata').get('datePublished')
    data['dateReserved'] = cve_data.get('cveMetadata').get('dateReserved')  # used as partition key
    data['dateUpdated'] = cve_data.get('cveMetadata').get('dateUpdated')
    data['descriptions'] = cve_data.get('containers').get('cna').get('descriptions')
    data['affected'] = cve_data.get('containers').get('cna').get('affected')
    data['metrics'] = cve_data.get('containers').get('cna').get('metrics')
    return data


async def create_all_the_items(container, batch, resource_id):
    await asyncio.wait(
        [asyncio.create_task(container.create_item(item)) for item in batch]
    )
    print(f"[{resource_id}][DB] Batch of {len(batch)} items done!")


async def main():
    start_time = time.time()

    # get the current working directory
    current_working_directory = Path.cwd()
    local_dir = os.path.join(current_working_directory, "cverepo")

    # CVE project repo. Publicly accessible for use
    repo_url = "https://github.com/CVEProject/cvelistV5.git"
    print(f"Cloning repo: {repo_url}")

    # Clone the cve repo to local_dir
    repo = Repo.clone_from(repo_url, local_dir)
    print(f"Successfully cloned  repo: {repo_url}")

    # Get path to cve files
    cve_dir = os.path.join(current_working_directory, "cverepo", "cves")

    # Sanity check there is a cves folder
    if os.path.isdir(cve_dir):
        print(f"The cve repository at {cve_dir} does exit")
        batch_size = 0
        batch = []

        # Recursively walk through all json files in cve file name format
        files = [f for f in pathlib.Path(cve_dir).glob("**/CVE-*.json")]
        print(f"Total of {len(files)} cve files to be processed")

        # Setup Azure credential
        credential = DefaultAzureCredential()

        try:
            # Setup cosmosdb client for asynchronous write
            async with CosmosClient(url=DB_URL, credential=KEY) as client:
                db = client.get_database_client(DATABASE_NAME)
                container = db.get_container_client(CONTAINER_NAME)

                for file in files:
                    with open(file, 'r') as cve:
                        content = json.load(cve)
                        # Pick a few properties out, we don't need the whole lot
                        # Add to a batch list of MAX_BATCH_SIZE
                        data = extract_cve_data(content)
                        batch.append(data)
                        batch_size += 1

                        # When batch is 'full' save to db and resent counters
                        # Sending in batches reduces payload volume of writes to db
                        if batch_size == MAX_BATCH_SIZE:
                            print(f"Reached batch of {batch_size}")
                            await asyncio.wait(
                                [asyncio.create_task(container.create_item(item) for item in batch)]
                            )
                            print(f"Saved batch of {batch_size}")
                            batch_size = 0
                            batch = []
                            print(f"Reset batch to {len(batch)}")

        except exceptions.CosmosResourceNotFoundError as e:
            print(f"Error adding batch: {e}")
        except exceptions.CosmosResourceExistsError as e:
            print(f"Error adding batch: {e}")
        except exceptions.CosmosHttpResponseError as e:
            print(f"Error adding batch: {e}")
        except exceptions.CosmosClientTimeoutError as e:
            print(f"Error adding batch: {e}")

    else:
        print(f"The cve repository ar {cve_dir} does not exit")

    # Removing directory, not massively relevant as job will exist, just due diligence
    shutil.rmtree(local_dir, ignore_errors=True)

    # Log how log it took
    elapsed_time = time.time() - start_time
    print(f'Elapsed time: {format_timespan(elapsed_time)}')


if __name__ == "__main__":
    asyncio.run(main())
