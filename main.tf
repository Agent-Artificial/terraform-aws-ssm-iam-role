module "label" {
  #  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=0.1.3"
  source     = "../terraform-terraform-label"
  attributes = var.attributes
  delimiter  = var.delimiter
  name       = var.name
  namespace  = var.namespace
  stage      = var.stage
  tags       = var.tags
}

locals {
  policy_only = 0
  #length(var.assume_role_arns) > 0 ? 1 : 0
  params =  formatlist("arn:aws:ssm:%s:%s:parameter/%s",
    var.region,
    var.account_id,
    var.ssm_parameters)

}

data "aws_kms_key" "default" {
  key_id = var.kms_key_reference
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      variable = "aws:SourceAccount"
      values = [var.account_id]
    }
    condition {
      test = "ArnEquals"
      variable = "aws:SourceArn"
      values = ["arn:aws:ssm:${var.region}:${var.account_id}:*"]
    }
    
  # statement {
  #   effect  = "Allow"
  #   actions = ["sts:AssumeRole"]

  #   principals {
  #     type        = "AWS"
  #     #identifiers = var.assume_role_arns
  #   }
  # }
  }
}


output test {
  value = local.params
}

data "aws_iam_policy_document" "default" {
  statement {
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = var.ssm_actions
    resources = local.params
    effect    = "Allow"
  }

  statement {
    actions   = ["kms:Decrypt"]
    resources = ["${data.aws_kms_key.default.arn}"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "default" {
  name        = module.label.id
  description = "Allow SSM actions"
  policy      = data.aws_iam_policy_document.default.json
}

resource "aws_iam_role" "default" {
  count = local.policy_only

  name                 = module.label.id
  assume_role_policy   = join("", data.aws_iam_policy_document.assume_role.*.json)
  description          = "IAM Role with permissions to perform actions on SSM resources"
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "default" {
  count = local.policy_only

  role       = join("", aws_iam_role.default.*.name)
  policy_arn = join("", aws_iam_policy.default.*.arn)
}
