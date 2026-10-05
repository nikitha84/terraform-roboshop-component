locals {
    ami_id = data.aws_ami.joindevops.id
    vpc_id = data.aws_ssm_parameter.vpc_id.value
    sg_id = data.aws_ssm_parameter.sg_id.value
    
    private_subnet_id = split("," , data.aws_ssm_parameter.private_subnet_ids.value)[0]
    private_subnet_ids = split("," , data.aws_ssm_parameter.private_subnet_ids.value)#for asg need 2 azs

    tg_port = "${var.components}" == "frontend" ? 80 : 8080

    health_check_path = "${var.components}" == "frontend" ?  "/" : "/health"

    frontend_alb_listener_arn = data.aws_ssm_parameter.frontend_alb_listener_arn.value
    backend_alb_listener_arn = data.aws_ssm_parameter.backend_alb_listener_arn.value
    listener_arn = "${var.components}" == "frontend" ? local.frontend_alb_listener_arn : local.backend_alb_listener_arn

    host_header = "${var.components}" == "frontend" ? "${var.project_name}-${var.environment}.${var.domain_name}" : "${var.components}.backend-alb-${var.environment}.${var.domain_name}"

    common_tags ={
        Project = var.project_name
        Environment = var.environment
        Terraform = "true"

    }
} 
