resource "time_sleep" "public_subnets_ready" {
  for_each       = azurerm_subnet.public
  create_duration = var.subnet_propagation_wait

  depends_on = [
    azurerm_subnet.public[each.key]
  ]
}

resource "time_sleep" "private_subnets_ready" {
  for_each       = azurerm_subnet.private
  create_duration = var.subnet_propagation_wait

  depends_on = [
    azurerm_subnet.private[each.key]
  ]
}


