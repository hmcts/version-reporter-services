import asyncio
import os
import time
from datetime import datetime as dt

from azure.cosmos import exceptions
from azure.cosmos.aio import CosmosClient

# Environment variables passed in via sds flux configuration
endpoint = os.getenv("COSMOS_DB_URI")
key = os.getenv("COSMOS_KEY")
database_name = os.getenv("COSMOS_DB_NAME", "reports")
container_name = os.getenv("COSMOS_DB_CONTAINER", "cveinfo")


def get_formatted_time():
    now = dt.now()
    return now.strftime("%I:%M:%S %p")


async def add_batch(batch):
    try:
        async with CosmosClient(url=endpoint, credential=key) as client:
            database = client.get_database_client(database_name)
            container = database.get_container_client(container_name)

            timer = time.time()
            print(f"Starting Concurrent Batched Item Creation: {get_formatted_time()}.")
            await create_all_the_items(container, batch)

            concurrent_batch_time = time.time() - timer
            print(f"Time taken: {concurrent_batch_time:.2f} sec")
            time.sleep(2.5)
    except exceptions.CosmosResourceNotFoundError as e:
        print(f"Error adding batch: Error: {e}")
    except exceptions.CosmosResourceExistsError as e:
        print(f"Error adding batch: Error: {e}")
    except exceptions.CosmosHttpResponseError as e:
        print(f"Error adding batch: Error: {e}")
    except exceptions.CosmosClientTimeoutError as e:
        print(f"Error adding batch: Error: {e}")


def create_or_update(container, item):
    cve_id = item.get('cveId')
    document = container.query_items(
        query='SELECT * FROM c WHERE c.cveId = @cveId',
        parameters=[dict(name='@cveId', value=cve_id)],
        enable_cross_partition_query=True)

    if document:
        item.pop('id', None)
        document.update(item)
        container.upsert_item(body=document)
    else:
        container.upsert_item(body=document)


async def create_all_the_items(container, batch):
    await asyncio.wait(
        [asyncio.create_task(create_or_update(container, item)) for item in batch]
    )
    print(f"Batch of {len(batch)} items done!")
