import os
import datetime
from azure.storage.blob import BlobServiceClient
from utility import get_headers_file


class Storage:
    account_url: str
    container_name: str
    shared_access_key: str
    blob_service_client: BlobServiceClient

    def __init__(self):
        self.account_url = os.getenv("AZURE_STORAGE_URL")
        self.container_name = os.getenv("AZURE_STORAGE_CONTAINER")
        self.shared_access_key = os.getenv("AZURE_STORAGE_ACCESS_KEY")
        self.blob_service_client = BlobServiceClient(self.account_url, credential=self.shared_access_key)
        print("Authentication with access key successful")

    def get_blob_service_client(self):
        return self.blob_service_client

    def create_container(self, blob_service_client):
        container_client = blob_service_client.get_container_client(container=self.container_name)
        if not container_client.exists():
            print(f"Creating container {self.container_name}")
            container_client.create_container(public_access="BLOB")

    def create_append_blob(self, append_blob_name, blob_service_client):
        blob_client = blob_service_client.get_blob_client(container=self.container_name, blob=append_blob_name)

        if not blob_client.exists():
            blob_client.create_append_blob()
            print(f"Creating blob {append_blob_name} in {self.container_name} container")
            headers_file = get_headers_file()
            with open(file=headers_file, mode="rb") as data:
                blob_client.append_block(data=data)

            print(f"Added headers to {append_blob_name}")

        return blob_client

    @staticmethod
    def append_data_to_blob(data, append_blob_name, blob_client):
        print(f"Adding data to Azure Storage as blob: {append_blob_name}")
        blob_client.append_block(data=data)
        print(f"{append_blob_name} successfully updated")

    @staticmethod
    def get_append_blob_name():
        today = datetime.date.today()
        report_name = f"{today.strftime('%Y-%m')}-running.csv"
        return report_name

