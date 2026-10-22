output "website_url" {
  value       = "http://${aws_lb.this.dns_name}"
  description = "Open the campaign site here. HTTP only, as required by the assignment."
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "health_url" {
  value = "http://${aws_lb.this.dns_name}/health"
}

output "asg_name" {
  value = aws_autoscaling_group.web.name
}

output "target_group_arn" {
  value = aws_lb_target_group.web.arn
}

output "launch_template_id" {
  value = aws_launch_template.web.id
}

output "sns_topic_arn" {
  value = aws_sns_topic.events.arn
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnets_by_az" {
  value = {
    for i, az in local.azs : az => {
      public  = aws_subnet.public[i].id
      private = aws_subnet.private[i].id
    }
  }
}

output "resolved_ami_id" {
  value = local.ami
}
