variable "zone" {
  type        = object({ id = string })
  description = "Route53 zone within which to add records"
}

variable "default_ttl" {
  type        = number
  description = "TTL in seconds for records which do not specify one explicitly"
}

variable "records" {
  type        = set(object({ name = string, type = string, records = list(string) }))
  description = "List of records to create"
}
