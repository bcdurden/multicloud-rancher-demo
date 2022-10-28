resource "aws_iam_role_policy" "ssm_policy" {
  name = "${var.prefix}-ssm_policy"
  role = aws_iam_role.ssm_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "Stmt1629387563127"
        Action = [
          "ssm:CreateDocument",
          "ssm:DeleteDocument",
          "ssm:DescribeDocument",
          "ssm:DescribeDocumentParameters",
          "ssm:DescribeDocumentPermission",
          "ssm:GetDocument",
          "ssm:ListDocuments",
          "ssm:SendCommand",
          "ssm:UpdateDocument",
          "ssm:UpdateDocumentDefaultVersion",
          "ssm:UpdateDocumentMetadata"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "ssm_role" {
  name = "${var.prefix}-ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.prefix}-ssm_profile"
  role = "${aws_iam_role.ssm_role.name}"
}

data "aws_iam_policy" "ssmcore" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm-attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = data.aws_iam_policy.ssmcore.arn
}