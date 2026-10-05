resource "aws_instance" "main" {
    ami = local.ami_id
    instance_type ="t3.micro"
    vpc_security_group_ids= [local.sg_id]
    subnet_id = local.private_subnet_id

    tags = merge(
        local.common_tags,
        {
            Name = "${var.project_name}-${var.environment}-${var.components}"
        }
    )

}

resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id,
    
  ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.main.private_ip
    }
  
  provisioner "file" {
    source      = "bootstrap.sh" # Local file path
    destination = "/tmp/bootstrap.sh"  # Destination path on the server
  }
  provisioner "remote-exec" {
    inline = [
        "chmod +x /tmp/bootstrap.sh",
        #"sudo sh /tmp/bootstrp.sh "
        "sudo sh /tmp/bootstrap.sh ${var.components} ${var.environment}"

    ]
  }
}

resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on = [terraform_data.main] 
}

resource "aws_ami_from_instance" "main" {
  name               = "${var.components}-ami"
  source_instance_id = aws_instance.main.id
  depends_on = [aws_ec2_instance_state.main]

  tags = merge(
        local.common_tags,
        {
            Name = "${var.project_name}-${var.environment}-${var.components}-ami"
        }
    )
}

resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-${var.environment}-${var.components}"
  port        = local.tg_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  deregistration_delay = 60 # waiting period before deleting the instance

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 10
    path = local.health_check_path
    protocol = "HTTP"
    timeout = 2
    matcher = "200-299"
    port = local.tg_port
  }
} 

resource "aws_launch_template" "main" {
  name = "${var.project_name}-${var.environment}-${var.components}"
  image_id = aws_ami_from_instance.main.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.sg_id]

  #when we run tf apply, a new version will be created with new ami id
  update_default_version = true

  #tags attch to instances
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
        {
            Name = "${var.project_name}-${var.environment}-${var.components}"
        }
    )
  }

  ##tags attch to the volume created by instance
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
        {
            Name = "${var.project_name}-${var.environment}-${var.components}"
        }
    )

  }
 
    #tags attached to launch teplate
    tags = merge(
      local.common_tags,
        {
            Name = "${var.project_name}-${var.environment}-${var.components}"
        }
    )
}  

resource "aws_autoscaling_group" "main" {
  name                 = "${var.project_name}-${var.environment}-${var.components}"
  max_size             = 10
  min_size             = 1
  health_check_grace_period = 100 #start instance health check after 100sec
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false

  launch_template {
    id = aws_launch_template.main.id
    version = aws_launch_template.main.latest_version
  }
  vpc_zone_identifier  = local.private_subnet_ids 
  target_group_arns = [aws_lb_target_group.main.arn]
 
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 #atleast 50% of the instances shold be up
    }
    triggers = ["launch_template"]
  }

  dynamic "tag" { #loop tags
    for_each = merge(
      local.common_tags,
        {
            Name = "${var.project_name}-${var.environment}-${var.components}"
        }
    )
    content {
      key                 = tag.key
      propagate_at_launch = true
      value               = tag.value
    }
  }
  timeouts {
    delete = "15m"
  }

}

resource "aws_autoscaling_policy" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  name                   = "${var.project_name}-${var.environment}-${var.components}"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
      target_value = 75.0
  }
  
}

#listener rule
resource "aws_lb_listener_rule" "main" {
  listener_arn = local.listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [local.host_header]
    }
  }
}

#delete catalogue instance
resource "terraform_data" "main_local" {
  triggers_replace = [
    aws_instance.main.id,
  ]

  depends_on = [aws_autoscaling_policy.main]
  
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }
}