# Gatling Fargate Module

This Terraform module provisions the AWS resources needed to run Gatling load tests in ECS Fargate.  
It creates an ECS cluster, task definition, security group, CloudWatch logs, and an S3 bucket to store Gatling reports.  
The module is designed to be triggered on-demand from a CI/CD pipeline, so you only pay for the tasks when you run them.
---

## Example Usage

```hcl
module "gatling_fargate" {
  source       = "git::ssh://git@bitbucket.org/adaptavistlabs/module-aws-gatling.git//gatling-fargate?ref=v1.0.0"
  service_name = "gatling-runner"
  task_cpu     = 1024
  task_memory  = 2048
  vpc_id       = module.network.vpc_id
  region       = data.aws_region.current.name
  stage        = var.stage
  subnet_ids   = module.network.public_subnet_ids
  ecr_repo_url = "074742550667.dkr.ecr.us-west-2.amazonaws.com/shared-services/proxy-gatling"
  image_tag    = var.image_tag
  ecr_repo_arn = "arn:aws:ecr:us-west-2:074742550667:repository/shared-services/proxy-gatling"
}

