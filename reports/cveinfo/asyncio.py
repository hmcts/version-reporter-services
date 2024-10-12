import asyncio
import os
import time

from azure.cosmos import exceptions
from azure.cosmos.aio import CosmosClient

# Environment variables passed in via sds flux configuration
endpoint = os.getenv("COSMOS_DB_URI")
key = os.getenv("COSMOS_KEY")
database_name = os.getenv("COSMOS_DB_NAME", "reports")
container_name = os.getenv("COSMOS_DB_CONTAINER", "netflow")


async def add_batch(batch, resource_id):
    try:
        async with CosmosClient(url=endpoint, credential=key) as client:
            database = client.get_database_client(database_name)
            container = database.get_container_client(container_name)

            timer = time.time()
            print("Starting Concurrent Batched Item Creation.")
            await create_all_the_items(container, batch, resource_id)

            concurrent_batch_time = time.time() - timer
            print(f"Time taken: {concurrent_batch_time:.2f} sec")
    except exceptions.CosmosResourceNotFoundError as e:
        print(f"Error adding batch: {batch}\n Error: {e}")
    except exceptions.CosmosResourceExistsError as e:
        print(f"Error adding batch: {batch}\n Error: {e}")
    except exceptions.CosmosHttpResponseError as e:
        print(f"Error adding batch: {batch}\n Error: {e}")
    except exceptions.CosmosClientTimeoutError as e:
        print(f"Error adding batch: {batch}\n Error: {e}")


async def create_all_the_items(container, batch, resource_id):
    await asyncio.wait(
        [asyncio.create_task(container.create_item(item)) for item in batch]
    )
    print(f"Batch of {len(batch)} items done!")
