output "cosmosdb_endpoint" {
  value = azurerm_cosmosdb_account.this.endpoint
}

output "cosmosdb_url" {
  value = "${azurerm_cosmosdb_account.this.id}.documents.azure.com"
}
