resource "time_sleep" "subnets_ready" {
  create_duration = var.subnet_propagation_wait

  depends_on = [
    azurerm_subnet.public,
    azurerm_subnet.private
  ]
}


