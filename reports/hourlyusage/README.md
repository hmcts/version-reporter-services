# Hourly Reports Microservice
The Version Reporter Service MicroServices Project

### Hourly Report Cron

The Hourly report runs a cron job every 5min pass every hour and executes 2 querries agaist
microsoft's resource graph api to determine 2 things:

- How many VM's are running at the hour at 5 past
- How many VMSS's are running at the hour at 5 past

The results of these response are both combined and grouped per subscriptions per group and
total VM's.<br/>

For example (VM):
<pre>
A result from ARG of:    
    subA | skuA
    subA | skuA
    subA | skuB

Will result to:
    subA | skuA | 2
    subA | skuB | 1
</pre>
<br>
For example (VMSS):
<pre>
A result from ARG of:    
    subA | skuA | 2
    subA | skuA | 3
    subA | skuB | 2

Will result to:
    subA | skuA | 5
    subA | skuB | 2
</pre>
<br>
The final result would be:
<pre>
A final result would be:
    subA | skuA | 7
    subA | skuB | 3
</pre>

The cron job run on the production AKS cluster as running on any other environment is not ideal
due to auto shutdowns in all nonprod environments.

This repo produces an image stored in [sdshmctspublic](https://portal.azure.com/#@HMCTS.NET/resource/subscriptions/5ca62022-6aa2-4cee-aaa7-e7536c8d566c/resourceGroups/sds-acr-rg/providers/Microsoft.ContainerRegistry/registries/sdshmctspublic/repository) ACR, the Cron job is deployed using the [sds-flux-config](https://github.com/hmcts/sds-flux-config) repo.
Results are stored as a CSV file on Azure [finops](https://portal.azure.com/#@HMCTS.NET/resource/subscriptions/1baf5470-1c3e-40d3-a6f7-74bfbce4b348/resourceGroups/finopsdataptlrg/providers/Microsoft.Storage/storageAccounts/finopsdataptlsa/overview) storage account.