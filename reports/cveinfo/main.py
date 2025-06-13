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

import logging

MAX_BATCH_SIZE = int(os.getenv("MAX_BATCH_SIZE", 500))

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
logger = logging.getLogger(__name__)
# Reduce Azure SDK logging noise
logging.getLogger("azure.core.pipeline.policies.http_logging_policy").setLevel(logging.ERROR)
logging.getLogger("azure.cosmos").setLevel(logging.ERROR)


# Utility used to cheery pick cve object
def extract_cve_data(job_time, cve_data):
    """
    Safely extract relevant fields from a CVE JSON object for database insertion.
    Handles missing keys gracefully.
    """
    def get_nested(d, *keys, default=None):
        for key in keys:
            if isinstance(d, dict):
                d = d.get(key, default)
            else:
                return default
        return d

    data = {
        'id': str(uuid.uuid4()),
        'cveId': get_nested(cve_data, 'cveMetadata', 'cveId'),
        'state': get_nested(cve_data, 'cveMetadata', 'state'),
        'dataType': cve_data.get('dataType'),
        'dataVersion': cve_data.get('dataVersion'),
        'assignerShortName': get_nested(cve_data, 'cveMetadata', 'assignerShortName'),
        'datePublished': get_nested(cve_data, 'cveMetadata', 'datePublished'),
        'dateReserved': get_nested(cve_data, 'cveMetadata', 'dateReserved'),
        'dateUpdated': get_nested(cve_data, 'cveMetadata', 'dateUpdated'),
        'descriptions': get_nested(cve_data, 'containers', 'cna', 'descriptions'),
        'affected': get_nested(cve_data, 'containers', 'cna', 'affected'),
        'metrics': get_nested(cve_data, 'containers', 'cna', 'metrics'),
        'runTime': job_time
    }
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


def iter_cve_json_files(path):
    """
    Recursively yield all files matching 'CVE-*.json' under the given path.
    """
    path = pathlib.Path(path)
    for entry in path.iterdir():
        if entry.is_file() and entry.name.startswith("CVE-") and entry.suffix == ".json":
            yield entry
        elif entry.is_dir():
            yield from iter_cve_json_files(entry)


async def load_cve(job_time):
    start_time = time.time()

    # get the current working directory
    current_working_directory = Path.cwd()
    local_dir = os.path.join(current_working_directory, "cverepo")

    # CVE project repo. Publicly accessible for use
    repo_url = "https://github.com/CVEProject/cvelistV5.git"
    logger.info(f'Cloning repo: {repo_url}')

    # Clone the cve repo to local_dir (shallow clone, only latest commit)
    envs = dict()
    envs['sb'] = "--single-branch"
    repo = Repo.clone_from(repo_url, local_dir, env=envs, depth=1)
    if repo:
        logger.info(f'Successfully cloned repo: {repo_url}')

    # Get path to cve files
    cve_dir = os.path.join(current_working_directory, "cverepo", "cves")
    try:
        # Sanity check there is a cves folder
        if os.path.isdir(cve_dir):
            logger.info(f"The cve repository at {cve_dir} exists")
            batch = []
            total_files = 0
            # Process one subfolder at a time to reduce memory usage
            for year_folder in sorted(os.listdir(cve_dir)):
                year_path = os.path.join(cve_dir, year_folder)
                if not os.path.isdir(year_path):
                    continue
                logger.info(f"Processing folder: {year_path}")
                folder_file_count = 0
                for file in iter_cve_json_files(year_path):
                    with open(file, mode='r') as cve:
                        data = json.load(cve)
                        data = extract_cve_data(job_time, data)
                        batch.append(data)
                        folder_file_count += 1
                        total_files += 1
                        if len(batch) == MAX_BATCH_SIZE:
                            logger.info(f"Saving batch of {MAX_BATCH_SIZE} items from folder {year_folder}")
                            await save_and_reset_batch(batch)
                if batch:
                    logger.info(f"Saving batch of {len(batch)} items after folder {year_folder}")
                    await save_and_reset_batch(batch)
                logger.info(f"Finished processing folder: {year_path} ({folder_file_count} files)")
            if batch:
                logger.info(f"Saving remaining batch of {len(batch)} items after all folders")
                await save_and_reset_batch(batch, is_final=True)
            logger.info(f"Total files processed: {total_files}")
            # TODO: Clean old data
            # await remove_old_batch(job_time)
        else:
            logger.error(f"The cve repository at {cve_dir} does not exist")
    finally:
        # Removing directory, not massively relevant as job will exist, just due diligence
        shutil.rmtree(local_dir, ignore_errors=True)
        logger.info(f"Removed the cve repository")

    # Log how log it took
    elapsed_time = time.time() - start_time
    logger.info(f'Elapsed time: {format_timespan(elapsed_time)}')


async def save_and_reset_batch(batch, is_final=False):
    await add_batch(batch)
    # Logging is now handled in load_cve
    batch.clear()


async def main():
    job_time = get_job_run_time()
    logger.info(f"Starting job at {job_time}")
    await load_cve(job_time)


if __name__ == "__main__":
    asyncio.run(main())
