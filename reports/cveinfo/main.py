import asyncio
import datetime
import json
import os
import pathlib
import shutil
import time
import uuid
from pathlib import Path

from git import Repo
from humanfriendly import format_timespan

from save_to_db import add_batch

MAX_BATCH_SIZE = os.getenv("MAX_BATCH_SIZE", 1000)


# Utility used to cheery pick cve object
def extract_cve_data(job_time, cve_data):
    data = dict()
    data['id'] = f'{uuid.uuid4()}'
    data['cveId'] = cve_data.get('cveMetadata').get('cveId')
    data['state'] = cve_data.get('cveMetadata').get('state')
    data['dataType'] = cve_data.get('dataType')
    data['dataVersion'] = cve_data.get('dataVersion')
    data['assignerShortName'] = cve_data.get('cveMetadata').get('assignerShortName')
    data['datePublished'] = cve_data.get('cveMetadata').get('datePublished')
    data['dateReserved'] = cve_data.get('cveMetadata').get('dateReserved')  # used as partition key
    data['dateUpdated'] = cve_data.get('cveMetadata').get('dateUpdated')
    data['descriptions'] = cve_data.get('containers').get('cna').get('descriptions')
    data['affected'] = cve_data.get('containers').get('cna').get('affected')
    data['metrics'] = cve_data.get('containers').get('cna').get('metrics')
    data['runTime'] = job_time
    return data


def get_year():
    today = datetime.datetime.now()
    return today.strftime("%Y")


def get_job_run_time():
    today = datetime.datetime.now()
    return today.strftime("%H:%M:%S")


def filter_by_year(cve_filename):
    pattern = f"/{get_year()}/"
    if pattern in str(cve_filename):
        return True
    return False


async def load_cve(job_time):
    start_time = time.time()

    # get the current working directory
    current_working_directory = Path.cwd()
    local_dir = os.path.join(current_working_directory, "cverepo")

    # CVE project repo. Publicly accessible for use
    repo_url = "https://github.com/CVEProject/cvelistV5.git"
    print(f'Cloning repo: {repo_url}')

    # Clone the cve repo to local_dir
    envs = dict()
    envs['sb'] = "--single-branch"
    repo = Repo.clone_from(repo_url, local_dir, env=envs)
    if repo:
        print(f'Successfully cloned repo: {repo_url}')

    # Get path to cve files
    cve_dir = os.path.join(current_working_directory, "cverepo", "cves")
    try:
        # Sanity check there is a cves folder
        if os.path.isdir(cve_dir):
            print(f"The cve repository at {cve_dir} does exit")
            batch = []

            # Recursively walk through all json files in cve file name format
            for file in pathlib.Path(cve_dir).glob("**/CVE-*.json"):
                with open(file, mode='r') as cve:
                    # Pick a few properties out, we don't need the whole lot
                    data = json.load(cve)
                    data = extract_cve_data(job_time, data)

                    # Add to a batch
                    batch.append(data)

                    # When batch is 'full' save to db and reset counter
                    # Sending in batches reduces payload volume of writes to db
                    if len(batch) == MAX_BATCH_SIZE:
                        await add_batch(batch)
                        print(f"Saved batch of {MAX_BATCH_SIZE}")
                        batch = []

            # Save remaining batched items, at some point it would be less than MAX_BATCH_SIZE
            if len(batch) > 0:
                print(f"Saved remaining batch of {len(batch)}")
                await add_batch(batch)
                # Free allocated space for batch
                batch = []

            # TODO: Clean old data
            # await remove_old_batch(job_time)
        else:
            print(f"The cve repository ar {cve_dir} does not exit")
    finally:
        # Removing directory, not massively relevant as job will exist, just due diligence
        shutil.rmtree(local_dir, ignore_errors=True)
        print(f"Removed the cve repository")

    # Log how log it took
    elapsed_time = time.time() - start_time
    print(f'Elapsed time: {format_timespan(elapsed_time)}')


async def main():
    job_time = get_job_run_time()
    print(f"Starting job at {job_time}")
    await load_cve(job_time)


if __name__ == "__main__":
    asyncio.run(main())
