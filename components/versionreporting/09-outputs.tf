output "cosmosdb_endpoint" {
  value = env == "ptl" ? azurerm_cosmosdb_account.this.endpoint : null
}

output "cosmosdb_url" {
  value = env == "ptl" ? "${azurerm_cosmosdb_account.this.id}.documents.azure.com" : null
}
