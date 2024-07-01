output "cosmosdb_endpoint" {
  value = var.env == "ptl" ? azurerm_cosmosdb_account.this[0].endpoint : null
}

output "cosmosdb_url" {
  value = var.env == "ptl" ? "${azurerm_cosmosdb_account.this[0].id}.documents.azure.com" : null
}
