variable "zone" {
  type        = object({ id = string, name = string })
  description = "Route53 zone for the domain to verify"
}

variable "domain" {
  type        = string
  description = "The domain name to setup as a sending identity, defaults to zone.name, but can set to a subdomain"
  default     = ""
}
