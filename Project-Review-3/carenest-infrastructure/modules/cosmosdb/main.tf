resource "azurerm_cosmosdb_account" "cosmos" {
  name                          = "${var.project_name}-cosmos"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  offer_type                    = "Standard"
  kind                          = "MongoDB"
  mongo_server_version          = "4.2"
  automatic_failover_enabled    = false
  public_network_access_enabled = true

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  tags = var.tags
}

resource "azurerm_cosmosdb_mongo_database" "db" {
  name                = "carenest"
  resource_group_name = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = var.throughput
}

resource "azurerm_cosmosdb_mongo_collection" "users" {
  name                = "users"
  resource_group_name = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_mongo_database.db.name
  shard_key           = "_id"

  index {
    keys   = ["_id"]
    unique = true
  }
}

resource "azurerm_cosmosdb_mongo_collection" "appointments" {
  name                = "appointments"
  resource_group_name = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_mongo_database.db.name
  shard_key           = "patientId"

  index {
    keys   = ["_id"]
    unique = true
  }

  index {
    keys   = ["patientId"]
    unique = false
  }
}

resource "azurerm_cosmosdb_mongo_collection" "prescriptions" {
  name                = "prescriptions"
  resource_group_name = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_mongo_database.db.name
  shard_key           = "appointmentId"

  index {
    keys   = ["_id"]
    unique = true
  }

  index {
    keys   = ["appointmentId"]
    unique = false
  }
}

resource "azurerm_cosmosdb_mongo_collection" "notifications" {
  name                = "notifications"
  resource_group_name = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_mongo_database.db.name
  shard_key           = "userId"

  index {
    keys   = ["_id"]
    unique = true
  }

  index {
    keys   = ["userId"]
    unique = false
  }
}