variable "domain_name" {
  type        = string
  description = "Name of the primary hostname to request a certifcate for"
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "List of SANs to additionally attach to certificate"
  default     = []
}

variable "route53_zone" {
  type        = object({ id = string })
  description = "Public Route53 zone which includes the hostname and SANs to be used for adding validation records"
}
