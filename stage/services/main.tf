########################################
# Terraform Backend Configuration
########################################

data "terraform_remote_state" "mysql" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state-bucket-76474"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "us-east-2"
  }
}

########################################
# Data Sources
########################################

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Ubuntu 20.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

########################################
# Security Groups
########################################

# ALB security group
resource "aws_security_group" "alb" {
  name = "terraform-example-alb-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2/ASG instance security group
resource "aws_security_group" "instance" {
  name = "terraform-example-instance-sg"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################################
# Load Balancer
########################################

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = 404
    }
  }
}

########################################
# Target Group
########################################

resource "aws_lb_target_group" "asg_targets" {
  name     = "example-asg-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Forward ALL requests to the ASG
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg_targets.arn
  }
}

########################################
# Launch Template (Replacement for Launch Configuration)
########################################

resource "aws_launch_template" "example" {
  name_prefix   = "example-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  user_data = base64encode(
    templatefile("${path.module}/user-data.sh", {
      server_port = var.server_port
      db_address  = data.terraform_remote_state.mysql.outputs.address
      db_port     = data.terraform_remote_state.mysql.outputs.port
    })
  )

  network_interfaces {
    security_groups = [aws_security_group.instance.id]
  }
}

########################################
# Auto Scaling Group
########################################

resource "aws_autoscaling_group" "example" {
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.asg_targets.arn]
  health_check_type   = "ELB"

  min_size = 2
  max_size = 10

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "terraform-example-asg"
    propagate_at_launch = true
  }
}