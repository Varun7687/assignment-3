# Assignment 3: Campaign Site

This repository deploys the campaign website to Amazon Linux 2023 instances behind an Application Load Balancer (ALB). The intended design uses private web instances in an Auto Scaling group and a public ALB.

The existing resources identified during setup are the `northwind-campaign-alb` load balancer and `northwind-campaign-tg` target group. Reuse those assignment resources where appropriate; do not create duplicate ALBs or target groups.

## Repository contents

* `assignment-3-campaign-site/site/` — static website files served by Apache.
* `assignment-3-campaign-site/scripts/script.sh` — EC2 bootstrap script for Launch Template User Data.

The repository is [Varun7687/assignment-3](https://github.com/Varun7687/assignment-3), branch `assignment-3`.

## Architecture

```text
Internet
   |
Public ALB (HTTP :80, across two public subnets/AZs)
   |
Target group (HTTP :80, health check: /health)
   |
Auto Scaling group (Amazon Linux 2023 instances in two private subnets/AZs)
   |
One NAT Gateway provides private-instance outbound access
```

The VPC should have two public and two private subnets across two Availability Zones. The ALB is internet-facing. Web instances have no public IP and accept HTTP only from the ALB security group. The NAT Gateway enables private instances to install packages and clone the public GitHub repository during bootstrap.

## EC2 bootstrap script

Use `assignment-3-campaign-site/scripts/script.sh` as the User Data for the Launch Template. It is intended for Amazon Linux 2023 and runs as root when each new instance starts. It:

* Installs Apache, Git, and curl.
* Clones branch `assignment-3` of this repository and copies `assignment-3-campaign-site/site/` into `/var/www/html`.
* Requests an IMDSv2 token and adds the instance ID and Availability Zone to the page footer.
* Creates `/var/www/html/health`, which Apache serves at `/health` with HTTP 200.
* Starts and enables Apache, then checks the local health endpoint.

The script bootstraps an instance; it does not create the VPC, ALB, security groups, Launch Template, Auto Scaling group, scaling policy, or SNS topic. Configure those AWS resources separately. In the AWS Console, put the script contents in Launch Template → Advanced details → User data. Select the private subnets in the Auto Scaling group, not in the Launch Template.

Private instances need outbound internet access through the NAT Gateway for the package installation and Git clone. The repository must be publicly accessible at the URL above.

## Required AWS configuration

| Component | Required configuration |
|---|---|
| VPC | Two public and two private subnets across two AZs; internet gateway and routes for public subnets; private subnet default route through NAT. |
| NAT Gateway | One NAT Gateway is acceptable for this assignment; see the trade-off below. |
| ALB security group | Allow inbound HTTP, TCP 80, from `0.0.0.0/0`. |
| Web security group | Allow inbound HTTP, TCP 80, only from the ALB security group. Do not expose the instances' HTTP port directly to the internet. |
| Launch Template | Amazon Linux 2023, `t3.micro`, web security group, IMDSv2 required, project tags, and the bootstrap script as User Data. |
| Target group | Instance targets on HTTP 80; health-check path `/health`. |
| Auto Scaling group | Both private subnets; minimum 2, desired 2, maximum 4; attach the target group and use ELB health checks. Propagate project tags to launched instances. |
| Scaling policy | Target tracking on average ASG CPU utilization, target 50%. |
| SNS notifications | Configure the ASG to publish instance launch and terminate events to an SNS topic. Add and confirm an email subscription if email delivery is required. |

## Target-group health check

Recommended settings are:

| Setting | Value |
|---|---:|
| Protocol and port | HTTP on traffic port (80) |
| Path and success code | `/health`, `200` |
| Interval | 30 seconds |
| Timeout | 5 seconds |
| Healthy threshold | 2 consecutive successes |
| Unhealthy threshold | 3 consecutive failures |

A 30-second interval is a moderate check frequency. Requiring two successful checks avoids marking a target healthy after one transient response; requiring three failures avoids removing it for one brief delay. The five-second timeout gives a simple Apache health response time to complete while remaining shorter than the interval. Allow enough health-check grace time in the Auto Scaling group for package installation and the repository clone to finish.

## Single-NAT cost and availability trade-off

A single NAT Gateway avoids the fixed hourly cost of running one in each AZ. However, private-subnet traffic from the other AZ crosses AZs and may incur cross-AZ data-transfer charges. Both private subnets also depend on the NAT Gateway's AZ for outbound internet access. If that NAT Gateway or its AZ is unavailable, instances in both AZs lose that outbound path. This saves cost but is less resilient than one NAT Gateway per AZ.

## Verification checklist

Before marking the assignment complete, verify in AWS that:

* The ALB spans the two public subnets and forwards HTTP traffic to `northwind-campaign-tg`.
* The target group's health-check path is `/health` and it has two healthy targets when the Auto Scaling group's desired capacity is 2.
* The Auto Scaling group spans both private subnets, has min/desired/max values of 2/2/4, and uses ELB health checks.
* The Launch Template requires IMDSv2 and includes the bootstrap script and project tags.
* The CPU target-tracking policy uses a 50% target and the ASG sends launch and terminate notifications to SNS.
* The ALB website loads, the footer shows an instance ID and AZ, and `http://<ALB-DNS-name>/health` returns HTTP 200.

## Troubleshooting and cleanup

* Check `/var/log/script.sh.log` on an instance for bootstrap output. A failed Git clone or package install can indicate missing outbound access from the private subnet.
* If the target is unhealthy, confirm the instance security group allows port 80 from the ALB security group and that Apache serves `/health`.
* When finished, remove only the resources created for this assignment. Take care not to delete existing ALB, target-group, or VPC resources that you still need.
