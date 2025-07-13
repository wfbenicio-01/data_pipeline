variable "region" {
  type    = string
  default = "sa-east-1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "fallback_subnet_id" {
  type        = string
  description = "Subnet ID for EC2 fallback"
}

variable "size_threshold" {
  type        = number
  default     = 10485760
  description = "Max file size bytes for Lambda"
}

variable "opensearch_host" {
  type        = string
  description = "OpenSearch endpoint host"
}

variable "opensearch_index" {
  type        = string
  description = "OpenSearch index name"
}

variable "opensearch_user" {
  type        = string
  description = "OpenSearch basic auth user"
}

variable "opensearch_pass" {
  type        = string
  description = "OpenSearch basic auth password"
}
