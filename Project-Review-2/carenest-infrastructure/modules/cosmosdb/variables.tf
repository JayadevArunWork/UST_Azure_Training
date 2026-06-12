variable "project_name" {
  type = string
}
variable "location" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "throughput" {
  type = number
}
variable "keyvault_id" {
  type = string
}
variable "tags" {
  type = map(string)
}