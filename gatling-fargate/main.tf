data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "this" {
  name = "${var.service_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  lifecycle {
    prevent_destroy = true
  }
}

module "ecs-container-definition" {
  source          = "cloudposse/ecs-container-definition/aws"
  version         = "0.61.2"
  container_image = "${var.ecr_repo_url}:${var.image_tag}"
  container_name  = var.service_name
  essential       = true
  # no port_mappings for a pure client
  port_mappings = []
  environment = [
    {
      name : "EB_ENVIRONMENT",
      value : var.stage
    },
    { name : "RESULTS_BUCKET",
      value : aws_s3_bucket.gatling_results.bucket
    }
  ]
  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.this.name
      awslogs-region        = var.region
      awslogs-stream-prefix = var.service_name
    }
  }
}

resource "aws_ecs_task_definition" "fargate" {
  family = var.service_name

  container_definitions = jsonencode([
    module.ecs-container-definition.json_map_object,
  ])

  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  requires_compatibilities = ["FARGATE"]
}

resource "aws_security_group" "fargate" {
  name        = "${var.service_name}-ecs-tasks-security-group"
  description = "Allows Gatling tasks to generate outbound load; no inbound required"
  vpc_id      = var.vpc_id

  # No ingress rules needed
  # ingress {}

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "gatling_results" {
  bucket = "gatling-test-results-${data.aws_caller_identity.current.account_id}-${var.region}"
}

resource "aws_s3_bucket_versioning" "gatling_results" {
  bucket = aws_s3_bucket.gatling_results.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gatling_results" {
  bucket = aws_s3_bucket.gatling_results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "gatling_results" {
  bucket = aws_s3_bucket.gatling_results.id

  rule {
    id     = "expire-reports"
    status = "Enabled"

    expiration {
      days = 30 # keep reports 30 days, tweak as needed
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name_prefix       = var.service_name
  retention_in_days = 90
}

resource "aws_iam_role" "execution_role" {
  name_prefix        = "${var.service_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_document.json
}

data "aws_iam_policy_document" "assume_role_policy_document" {
  statement {
    sid     = "AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "execution_policy" {
  name_prefix = "${var.service_name}-execution-role-policy"
  role        = aws_iam_role.execution_role.name
  policy      = data.aws_iam_policy_document.execution_policy_document.json
}

data "aws_iam_policy_document" "execution_policy_document" {
  statement {
    sid       = "Logging"
    effect    = "Allow"
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
  }

  statement {
    sid       = "ECRPull"
    effect    = "Allow"
    resources = [var.ecr_repo_arn]

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:ListImages",
    ]
  }

  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    resources = ["*"]

    actions = ["ecr:GetAuthorizationToken"]
  }
}

resource "aws_iam_role" "task_role" {
  name_prefix        = "${var.service_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_document.json
}

resource "aws_iam_role_policy" "task" {
  name_prefix = "${var.service_name}-task-role-policy"
  role        = aws_iam_role.task_role.id
  policy      = data.aws_iam_policy_document.task_policy_document.json
}

data "aws_iam_policy_document" "task_policy_document" {

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DescribeParameters"
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:ListBucket", "s3:GetObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.gatling_results.bucket}", "arn:aws:s3:::${aws_s3_bucket.gatling_results.bucket}/*"]
  }

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Decrypt"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_sns_topic" "gatling_complete" {
  name = "gatling-run-complete"
}

# Allow EventBridge to publish to the topic
data "aws_iam_policy_document" "sns_policy" {
  statement {
    sid     = "AllowEventBridgePublish"
    effect  = "Allow"
    actions = ["sns:Publish"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [aws_sns_topic.gatling_complete.arn]
  }
}

resource "aws_sns_topic_policy" "policy" {
  arn    = aws_sns_topic.gatling_complete.arn
  policy = data.aws_iam_policy_document.sns_policy.json
}

# EventBridge rule
resource "aws_cloudwatch_event_rule" "gatling_stopped" {
  name        = "gatling-task-stopped"
  description = "Notify when gatling tasks stop"
  event_pattern = jsonencode({
    source        = ["aws.ecs"]
    "detail-type" = ["ECS Task State Change"]
    detail = {
      clusterArn = [aws_ecs_cluster.this.arn]
      lastStatus = ["STOPPED"]
      group      = [{ prefix = "family:${aws_ecs_task_definition.fargate.family}" }]
    }
  })
}

# Target SNS
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.gatling_stopped.name
  target_id = "sns"
  arn       = aws_sns_topic.gatling_complete.arn

  input_transformer {
    input_paths = {
      task   = "$.detail.taskArn"
      family = "$.detail.group"
      stop   = "$.detail.stoppedReason"
      code   = "$.detail.containers[0].exitCode"
      reason = "$.detail.containers[0].reason"
      time   = "$.detail.stoppedAt"
    }

    # Valid JSON object (no external quoting needed)
    input_template = <<EOF
{
  "task": "<task>",
  "time": "<time>",
  "family": "<family>",
  "exitCode": "<code>",
  "containerReason": "<reason>",
  "taskReason": "<stop>"
}
EOF
  }
}

# Email subscription
resource "aws_sns_topic_subscription" "gatling_email" {
  topic_arn = aws_sns_topic.gatling_complete.arn
  protocol  = "email"
  endpoint  = var.notify_email
}