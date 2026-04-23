import asyncio
import os
import time
from datetime import datetime as dt
import logging

from azure.cosmos import exceptions
from azure.cosmos.aio import CosmosClient

# Environment variables passed in via sds flux configuration
endpoint = os.getenv("COSMOS_DB_URI")
key = os.getenv("COSMOS_KEY")
database_name = os.getenv("COSMOS_DB_NAME", "reports")
container_name = os.getenv("COSMOS_DB_CONTAINER", "cveinfo")

# Setup logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_formatted_time():
    now = dt.now()
    return now.strftime("%I:%M:%S %p")


async def add_batch(batch):
    try:
        async with CosmosClient(url=endpoint, credential=key) as client:
            database = client.get_database_client(database_name)
            container = database.get_container_client(container_name)

            timer = time.time()
            logger.info(f"Starting Concurrent Batched Item Creation: {get_formatted_time()}.")
            await create_all_the_items(container, batch)

            concurrent_batch_time = time.time() - timer
            logger.info(f"Time taken: {concurrent_batch_time:.2f} sec")
            # Use asyncio.sleep instead of time.sleep in async context
            await asyncio.sleep(1)
    except exceptions.CosmosResourceNotFoundError as e:
        logger.error(f"Error adding batch: Error: {e}")
    except exceptions.CosmosResourceExistsError as e:
        logger.error(f"Error adding batch: Error: {e}")
    except exceptions.CosmosHttpResponseError as e:
        logger.error(f"Error adding batch: Error: {e}")
    except exceptions.CosmosClientTimeoutError as e:
        logger.error(f"Error adding batch: Error: {e}")
    except Exception as e:
        logger.error(f"Unexpected error adding batch: {e}")


# Expose concurrency and delay settings via environment variables
MAX_CONCURRENT_UPSERTS = int(os.getenv("MAX_CONCURRENT_UPSERTS", 10))
DELAY_BETWEEN_BATCHES = float(os.getenv("DELAY_BETWEEN_BATCHES", 0.5))


async def create_all_the_items(container, batch, max_concurrent=None, delay_between_batches=None):
    if max_concurrent is None:
        max_concurrent = MAX_CONCURRENT_UPSERTS
    if delay_between_batches is None:
        delay_between_batches = DELAY_BETWEEN_BATCHES
    semaphore = asyncio.BoundedSemaphore(max_concurrent)

    async def upsert_item(item):
        async with semaphore:
            cve_id = item.get("cveId")
            query = "SELECT * FROM c WHERE c.cveId = @cveId"
            items = [i async for i in container.query_items(
                query=query,
                parameters=[{"name": "@cveId", "value": cve_id}]
            )]
            if items:
                existing = items[0]
                item['id'] = existing['id']  # Ensure id is set for replace
                await container.replace_item(existing['id'], item)
            else:
                await container.create_item(item)

    await asyncio.gather(*(upsert_item(item) for item in batch))
    logger.info(f"Batch of {len(batch)} items upserted!")
    if delay_between_batches > 0:
        await asyncio.sleep(delay_between_batches)

async def remove_old_batch(job_time):
  logger.info("Removing old doc")
  # call custom function on cosmosdb
