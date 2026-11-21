# Run once from your machine: the IAM role GitHub Actions assumes with OIDC (no stored keys).
# It can build and tear down one small network and one t4g.nano instance in us-east-1, and nothing bigger.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

# GitHub's OIDC subject for this repo, in its immutable form.
# Find yours with: gh api repos/OWNER/REPO/actions/oidc/customization/sub --jq .sub_claim_prefix
variable "github_sub_prefix" {
  type    = string
  default = "repo:dkojo@167027053/hybrid-iac@1466616373"
}

variable "state_bucket" {
  type    = string
  default = "danielkojomegbenu-tfstate"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "ci" {
  name = "github-hybrid-iac"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = ["${var.github_sub_prefix}:ref:refs/heads/main", "${var.github_sub_prefix}:pull_request"] }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ci" {
  name = "provision-hybrid-aws-side"
  role = aws_iam_role.ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Network"
        Effect = "Allow"
        Action = [
          "ec2:Describe*", "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
          "ec2:ImportKeyPair", "ec2:DeleteKeyPair", "ec2:TerminateInstances",
        ]
        Resource  = "*"
        Condition = { StringEquals = { "aws:RequestedRegion" = "us-east-1" } }
      },
      {
        Sid       = "OnlyTinyInstances"
        Effect    = "Allow"
        Action    = "ec2:RunInstances"
        Resource  = "arn:aws:ec2:us-east-1:*:instance/*"
        Condition = { StringEquals = { "ec2:InstanceType" = "t4g.nano" } }
      },
      {
        Sid    = "RunInstancesSupportingResources"
        Effect = "Allow"
        Action = "ec2:RunInstances"
        Resource = [
          "arn:aws:ec2:us-east-1::image/*", "arn:aws:ec2:us-east-1:*:subnet/*", "arn:aws:ec2:us-east-1:*:network-interface/*",
          "arn:aws:ec2:us-east-1:*:security-group/*", "arn:aws:ec2:us-east-1:*:key-pair/*", "arn:aws:ec2:us-east-1:*:volume/*",
        ]
      },
      {
        Sid      = "ResolveTheAmazonLinuxImage"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:us-east-1::parameter/aws/service/ami-amazon-linux-latest/*"
      },
      { Sid = "StateBucket", Effect = "Allow", Action = "s3:ListBucket", Resource = "arn:aws:s3:::${var.state_bucket}" },
      {
        Sid      = "StateObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.state_bucket}/hybrid-iac/*"
      },
    ]
  })
}

output "role_arn" { value = aws_iam_role.ci.arn }
