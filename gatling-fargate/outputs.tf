output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_id" {
  value = aws_ecs_cluster.this.id
}

output "fargate_vpc_id" {
  value = aws_security_group.fargate.vpc_id
}

output "results_bucket" {
  value = aws_s3_bucket.gatling_results.bucket
}