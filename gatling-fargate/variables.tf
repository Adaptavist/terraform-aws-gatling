variable "subnet_ids" {
  type        = list(string)
  description = "A list of subnets to associate with the service"
}

variable "vpc_id" {
  type        = string
  description = "VPC id where the service will be deployed"
}

variable "service_name" {
  type        = string
  description = "Name of the service"
}

variable "task_cpu" {
  type        = number
  description = "Number of cpu units used by the task. If the requires_compatibilities is FARGATE this field is required."
}

variable "task_memory" {
  type        = number
  description = "Amount (in MiB) of memory used by the task. If the requires_compatibilities is FARGATE this field is required."
}

variable "region" {
  type        = string
  description = "AWS Region this infrastructure will be deployed to"
}

variable "stage" {
  type        = string
  description = "Deployment stage. Should be one of dev | stg | prod"
}

variable "ecr_repo_arn" {
  type = string
}

variable "ecr_repo_url" {
  type = string
}

variable "image_tag" {
  type        = string
  description = "Container image tag to be used by the service"
}