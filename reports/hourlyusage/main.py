from json import loads

from graph import Graph
from storage import Storage
from utility import get_current_date_time


def run():
    """
    Process both virtual machines, virtual machine scale sets and postgres
    flexible servers running vms
    :return
    """
    start_time = get_current_date_time()
    print(f"Hourly report cron job started at: {start_time}")

    graph: Graph = Graph()
    storage: Storage = Storage()
    vm_vmss_output_data = None
    pg_vm_output_data = None
    pg_vm_active_output_data = None

    # Connect to resource manager, execute query and return the data
    try:
        # Process data for vms and vmss
        vm_vmss_output_data = process_vms_and_vmss(graph, start_time)

        # Process data for postgres flexible servers
        pg_vm_output_data = process_pg_vm(graph, start_time)

        # Process data for active postgres flexible servers
        pg_vm_active_output_data = process_pg_active_vm(graph, start_time)

    except Exception as ex:
        print('Exception | Resource manager:')
        print(ex)

    # Connect to storage account, save (append) the data
    try:
        print("\nConnecting to Azure Blob Storage")

        # Setup connection to the storage account
        blob_service_client = setup_storage(storage)

        # Process the combined vm and vmss data as save to storage account
        process_and_save_vm_vmss_data(blob_service_client, storage, vm_vmss_output_data)

        # Process all flexible postgres vm data as save to storage account
        process_and_save_pg_vm_data(blob_service_client, storage, pg_vm_output_data)

        # Process only flexible postgres that are currently active and save to storage account
        process_and_save_pg_active_vm_data(blob_service_client, storage, pg_vm_active_output_data)
    except Exception as ex:
        print('Exception | Storage:')
        print(ex)

    print(f"Hourly report cron job completed at: {get_current_date_time()}")


def process_and_save_vm_vmss_data(blob_service_client, storage, vm_vmss_output_data):
    """
    Processes and saves to storage account the combined results from vms and vmss query
    :param blob_service_client:
    :param storage:
    :param vm_vmss_output_data:
    :return:
    """
    # Create file name by month e.g. 2023-11-running.csv
    vm_vmss_append_blob_name = storage.get_append_blob_name()

    # Create a blob client using the local file name as the name for the blob
    vm_vmss_blob_client = storage.create_append_blob(vm_vmss_append_blob_name, blob_service_client)

    # Add data to end of file
    if vm_vmss_output_data:
        storage.append_data_to_blob(vm_vmss_output_data, vm_vmss_append_blob_name, vm_vmss_blob_client)
    else:
        print("No vm or vmss output data available to append.")


def process_and_save_pg_vm_data(blob_service_client, storage, pg_vm_output_data):
    """
    Processes and saves to storage account the results for postgres running vms
    :param blob_service_client:
    :param storage:
    :param pg_vm_output_data:
    :return:
    """
    # Create file name by month e.g. 2023-11-running-pg.csv
    pg_vm_append_blob_name = storage.get_append_blob_name("pg")

    # Create a blob client using the local file name as the name for the blob
    pg_blob_client = storage.create_append_blob(pg_vm_append_blob_name, blob_service_client)

    # Add data to end of file
    if pg_vm_output_data:
        storage.append_data_to_blob(pg_vm_output_data, pg_vm_append_blob_name, pg_blob_client)
    else:
        print("No flexible postgres vm output data available to append.")


def process_and_save_pg_active_vm_data(blob_service_client, storage, pg_vm_active_output_data):
    """
    Processes and saves to storage account the results for postgres running vms
    :param blob_service_client:
    :param storage:
    :param pg_vm_active_output_data:
    :return:
    """
    # Create file name by month e.g. 2023-11-running-pg-active.csv
    pg_vm_append_blob_name = storage.get_append_blob_name("pg-active")

    # Create a blob client using the local file name as the name for the blob
    pg_blob_client = storage.create_append_blob(pg_vm_append_blob_name, blob_service_client)

    # Add data to end of file
    if pg_vm_active_output_data:
        storage.append_data_to_blob(pg_vm_active_output_data, pg_vm_append_blob_name, pg_blob_client)
    else:
        print("No active flexible postgres vm output data available to append.")


def setup_storage(storage):
    # Create the BlobServiceClient object
    blob_service_client = storage.get_blob_service_client()

    # Create container if not exists
    storage.create_container(blob_service_client)

    return blob_service_client


def process_vms_and_vmss(graph, start_time):
    # Get vm data from MRG, Group result, total sku's per subscriptions
    vm_result = graph.process_arg_vm_data()

    # Get vmss data from MRG, Group result, sum totals per sku's
    vmss_result = graph.process_arg_vmss_data()

    # Join both results in one list and group by sub, sku and sum totals
    result = graph.process_combined_data(vm_result, vmss_result)

    # Time stamp the data
    graph.add_timestamp(result, start_time)

    # Convert to csv without header or index so it can be appended
    output_data = graph.get_csv(result)

    return output_data


def process_pg_vm(graph, start_time):
    # Get vm data from MRG, Group result, total sku's per subscriptions
    pg_vm_result = graph.process_arg_vm_data("pg")

    # Convert back to json for processing
    result = loads(pg_vm_result)

    # Time stamp the data
    graph.add_timestamp(result, start_time)

    # Convert to csv without header or index so it can be appended
    output_data = graph.get_csv(result)

    return output_data


def process_pg_active_vm(graph, start_time):
    # Get vm data from MRG, Group result, total sku's per subscriptions
    pg_vm_result = graph.process_arg_vm_data("pg-active")

    # Convert back to json for processing
    result = loads(pg_vm_result)

    # Time stamp the data
    graph.add_timestamp(result, start_time)

    # Convert to csv without header or index so it can be appended
    output_data = graph.get_csv(result)

    return output_data


if __name__ == '__main__':
    run()
