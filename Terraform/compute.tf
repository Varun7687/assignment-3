resource "aws_launch_template" "web" {
  name                   = "${var.project_name}-lt"
  description            = "Northwind AL2023 campaign servers: ${var.deployment_revision}"
  image_id               = local.ami
  instance_type          = "t3.micro"
  key_name               = var.existing_key_pair_name == "" ? null : var.existing_key_pair_name
  user_data              = base64encode(local.user_data)
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.web.name
  }

  # Subnets belong to the ASG; do not pin an AZ or subnet here.
  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [aws_security_group.web.id]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.project_name}-web" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${var.project_name}-web-volume" })
  }

  tag_specifications {
    resource_type = "network-interface"
    tags          = merge(local.common_tags, { Name = "${var.project_name}-web-eni" })
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${var.project_name}-asg"
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 4
  vpc_zone_identifier       = aws_subnet.private[*].id
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 180
  wait_for_capacity_timeout = "15m"
  wait_for_elb_capacity     = 2

  launch_template {
    id      = aws_launch_template.web.id
    version = tostring(aws_launch_template.web.latest_version)
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = 180
      skip_matching         = false
      auto_rollback         = true
    }
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "${var.project_name}-web" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Target tracking owns this value after the initial deployment.
  lifecycle {
    ignore_changes = [desired_capacity]
  }

  # Instances must not launch before NAT routes, SG rules, IAM and the listener work.
  depends_on = [
    aws_route.public_internet,
    aws_route_table_association.public,
    aws_route.private_nat,
    aws_route_table_association.private,
    aws_iam_role_policy_attachment.ssm,
    aws_vpc_security_group_ingress_rule.web_from_alb,
    aws_vpc_security_group_egress_rule.web_outbound,
    aws_vpc_security_group_egress_rule.alb_to_web,
    aws_lb_listener.http,
    aws_sns_topic_policy.autoscaling
  ]
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.project_name}-cpu-50"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 50
    disable_scale_in = false
  }
}
