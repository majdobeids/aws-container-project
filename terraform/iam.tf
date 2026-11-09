resource "aws_iam_role" "db" {
  name_prefix = "${var.project}-db-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "backup" {
  name = "${var.project}-backup-upload"
  role = aws_iam_role.db.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:PutObject",
          "s3:AbortMultipartUpload"
        ]

        Resource = "${aws_s3_bucket.backups.arn}/postgres/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "db" {
  name_prefix = "${var.project}-db-"
  role        = aws_iam_role.db.name
}
