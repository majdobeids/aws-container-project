output "web_public_ip" {
  description = "Public IP used to access the web server"
  value       = aws_instance.node["web"].public_ip
}

output "db_public_ip" {
  description = "Public IP used for SSH to the database server"
  value       = aws_instance.node["db"].public_ip
}

output "db_private_ip" {
  description = "Private IP used by Flask to connect to PostgreSQL"
  value       = aws_instance.node["db"].private_ip
}

output "backup_bucket" {
  description = "S3 bucket used for database backups"
  value       = aws_s3_bucket.backups.id
}

output "aws_region" {
  description = "AWS region containing the project"
  value       = var.aws_region
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_instance.node["web"].public_ip}"
}
