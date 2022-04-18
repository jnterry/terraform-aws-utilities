variable "api" {
  type        = object({ id = string, root_resource_id = string })
  description = "API Gateway REST API object to attach the route to"
}

variable "parent_resource_id" {
  type        = string
  description = "ID of parent API gateway resource to attach the /contact path to - defaults to using the var.api.root_resource_id"
  default     = ""
}

variable "project" {
  type        = string
  description = "String used to customize various aws resource names (eg, the lambda handler, cloudwatch log group) - for consistancy, should be all lowercase with _ seperating words"
}

variable "path" {
  type        = string
  description = "The api path to attach to route to, defaults to 'contact' which places the route at /contact under var.parent_resource_id's url"
  default     = "contact"
}

variable "env" {
  type        = object({ DOMAIN = string, SENDER = string, RECEIVER = string, RECAPTCHA_SECRET = string })
  description = "Environment parameters passed through to the lambda code"
}
