variable "project_name" {
    type = string
}
variable "location" {
    type = string
}
variable "resource_group_name" {
    type = string
}
variable "pe_subnet_id" {
    type = string
}
variable "keyvault_id" {
    type = string
}
variable "appinsights_id" {
    type = string
}
variable "tags" {
    type = map(string)
}