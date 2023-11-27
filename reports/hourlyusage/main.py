from graph import Graph
from storage import Storage
from utility import get_current_date_time


def main():
    start_time = get_current_date_time()
    print(f"Hourly report cron job started at: {start_time}")

    graph: Graph = Graph()
    storage: Storage = Storage()

    # Connect to resource manager, execute query and return the data
    try:
        # Get vm data from MRG, Group result, total sku's per subscriptions
        vm_result = graph.process_arg_vm_data()

        # Get vmss data from MRG, Group result, sum totals per sku's
        vmss_result = graph.process_arg_vmss_data()

        # Join both results in one list and group by sub, sku and sum totals
        result = graph.process_combined_data(vm_result, vmss_result)

        # Time stamp the data
        graph.add_timestamp(result, start_time)

        # Convert to csv without header or index so it can be appended
        graph.save_as_csv(result)
    except Exception as ex:
        print('Exception | Resource manager:')
        print(ex)

    # Connect to storage account, save (append) the data
    try:
        print("Connecting to Azure Blob Storage")

        # Create the BlobServiceClient object
        blob_service_client = storage.get_blob_service_client()

        # Create container if not exists
        storage.create_container(blob_service_client)

        # Create file name by month e.g. 2023-11-running.csv
        append_blob_name = storage.get_append_blob_name()

        # Create a blob client using the local file name as the name for the blob
        blob_client = storage.create_append_blob(append_blob_name, blob_service_client)

        # Add data to end of file
        storage.append_data_to_blob(append_blob_name, blob_client)
    except Exception as ex:
        print('Exception | Storage:')
        print(ex)

    storage.remove_output_file()
    print(f"Hourly report cron job completed at: {get_current_date_time()}")


main()
