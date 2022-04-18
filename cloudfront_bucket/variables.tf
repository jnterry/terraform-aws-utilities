variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket to create"
}

variable "acl" {
  type        = string
  description = "The S3 bucket's ACL parameter"
  default     = "private"
}

variable "blocked_paths" {
  type        = list(string)
  description = "List of path patterns that should not be accessible, eg: [ '/private/*' ]"
  default     = []
}
