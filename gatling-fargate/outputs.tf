output "cluster_name" {
  description = "ECS cluster for Gatling tasks"
  value       = aws_ecs_cluster.this.name
}

output "task_definition" {
  description = "Full ARN of the task definition"
  value       = aws_ecs_task_definition.fargate.arn
}

output "task_family" {
  description = "Task family (without revision)"
  value       = aws_ecs_task_definition.fargate.family
}

output "subnets" {
  description = "List of subnet IDs for running Gatling tasks"
  value       = var.subnet_ids
}

output "security_group_id" {
  description = "Security group used by Gatling tasks"
  value       = aws_security_group.fargate.id
}

output "results_bucket" {
  description = "S3 bucket where Gatling reports are uploaded"
  value       = aws_s3_bucket.gatling_results.bucket
}
