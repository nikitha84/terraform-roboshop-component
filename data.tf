data "aws_ami" "joindevops" {
  most_recent = true
  owners = ["973714476881"]

  filter {
    name   = "name"
    values = ["Redhat-9-DevOps-Practice*"] # *-we will get ami_id with recent date
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"] 
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"] 
  }
} 

data "aws_ssm_parameter" "sg_id" {
  name = "/${var.project_name}/${var.environment}/${var.components}_sg_id"
}
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project_name}/${var.environment}/vpc_id"
}

data "aws_ssm_parameter" "backend_alb_listener_arn" {
  name = "/${var.project_name}/${var.environment}/backend_alb_listener_arn"
}

data "aws_ssm_parameter" "frontend_alb_listener_arn" {
  name = "/${var.project_name}/${var.environment}/frontend_alb_listener_arn"
}
data "aws_ssm_parameter" "private_subnet_ids" {
    name  = "/${var.project_name}/${var.environment}/private_subnet_ids"
}
