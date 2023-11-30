import pandas as pd
import azure.mgmt.resourcegraph as arg
from json import loads, dumps
from datetime import datetime
from azure.mgmt.resource import SubscriptionClient
from azure.identity import DefaultAzureCredential
from msgraph.generated.models.o_data_errors.o_data_error import ODataError
from utility import get_vm_query, get_vmss_query, remove_moj_subscriptions


class Graph:
    credential: DefaultAzureCredential
    subsClient: SubscriptionClient

    def __init__(self):
        self.credential = DefaultAzureCredential()
        self.subsClient = SubscriptionClient(self.credential)
        print("Authentication with default credential successful")

    def get_arg_data(self, query_type: str):
        arg_response = None
        try:
            query_string = None
            query_type = query_type.lower()
            if query_type == "vm":
                query_string = get_vm_query()
            elif query_type == "vmss":
                query_string = get_vmss_query()
            else:
                raise ODataError('Invalid query type!')

            # Execute the ARG query
            arg_response = self.get_resources(query_string)
            if arg_response:
                arg_response = arg_response.get("data")

        except ODataError as odata_error:
            print('Error:')
            if odata_error.error:
                print(odata_error.error.code, odata_error.error.message)

        return arg_response

    def get_resources(self, strQuery):
        subsRaw = []
        for sub in self.subsClient.subscriptions.list():
            subsRaw.append(sub.as_dict())

        subsList = []
        for sub in subsRaw:
            subsList.append(sub.get('subscription_id'))

        print(f"{len(subsList)} subscriptions with permissions to read from found")

        argClient = arg.ResourceGraphClient(self.credential)
        print("Authenticated with MS resource graph")

        argQueryOptions = arg.models.QueryRequestOptions(result_format="objectArray")

        argQuery = arg.models.QueryRequest(subscriptions=subsList, query=strQuery, options=argQueryOptions)
        argResults = argClient.resources(argQuery)

        result = {}
        if argResults:
            result = argResults.as_dict()

        return result

    def process_arg_vm_data(self):
        print("Executing running VM query")
        graph_result = self.get_arg_data("vm")
        graph_result = remove_moj_subscriptions(graph_result, "subscriptionName")  # skip moj subs
        df_vm = pd.DataFrame(graph_result)
        '''
        Group the data by subscription name and by sku's then aggregate by sku's and
        count how many per subscription. value is added to the 'total' column
        e.g.
            subA | skuA
            subA | skuA
            subA | skuB
        Will become:
            subA | skuA | 2
            subA | skuB | 1
        '''
        grouped_vm_data = df_vm.groupby(["subscriptionName", "sku"]).agg({'sku': ["count"]})
        grouped_vm_data.columns = ['total']
        grouped_vm_result = grouped_vm_data.reset_index()
        vm_result = grouped_vm_result.to_json(orient="records")
        return vm_result

    def process_arg_vmss_data(self):
        print("\nExecuting running VMSS query")
        graph_result = self.get_arg_data("vmss")
        graph_result = remove_moj_subscriptions(graph_result, "subscriptionName")  # skip moj subs
        df_vmss = pd.DataFrame(graph_result)
        '''
        Group the data by subscription name and by sku's then sum up all totals
        per subscription per sku
        e.g.
            subA | skuA | 1
            subA | skuA | 2
            subA | skuB | 1
        Will become:
            subA | skuA | 3
            subA | skuB | 1
        '''
        grouped_vmss_data = df_vmss.groupby(["subscriptionName", "sku"], as_index=True)['total'].sum()
        grouped_vmss_result = grouped_vmss_data.reset_index()
        vmss_result = grouped_vmss_result.to_json(orient="records")
        return vmss_result

    @staticmethod
    def process_combined_data(vm_result, vmss_result):
        # We convert the data back to dictionary, merge them and convert back to string
        all_results = dumps(loads(vm_result) + loads(vmss_result))

        graph_result = loads(all_results)
        df = pd.DataFrame(graph_result)
        '''
        Same outcome as per the process_arg_vmss_data as both result now have same columns i.e. 
        subscriptionName, sku, total
        '''
        grouped_data = df.groupby(["subscriptionName", "sku"], as_index=True)['total'].sum()
        result = grouped_data.reset_index()
        return loads(result.to_json(orient="records"))

    @staticmethod
    def get_csv(result):
        df = pd.DataFrame(result)
        output_data = df.to_csv(index=False, header=False, encoding="utf-8")
        return output_data

    @staticmethod
    def add_timestamp(result, start_time):
        runtime = datetime.strptime(start_time, "%Y-%m-%d %H:%M:%S")
        date = runtime.strftime("%Y-%m-%d")
        hour = runtime.strftime("%H")
        for row in result:
            row['date'] = date
            row['time'] = hour
