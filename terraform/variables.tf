variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "trendify"
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins server"
  type        = string
  default     = "c7i-flex.large"
}

variable "key_pair_name" {
  description = "Name of your existing AWS EC2 Key Pair"
  type        = string
  default     = "Proj-2-keypair"
}
