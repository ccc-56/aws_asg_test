provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      hashicorp-learn = "aws-asg"
    }
  }
  profile = "source"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"

  name = "main-vpc"
  cidr = "10.89.0.0/16"

  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.89.4.0/24", "10.89.5.0/24", "10.89.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_ami" "amazon-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_key_pair" "deployer1" {
  key_name   = "dong1"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDXOh4GPEvI2Eb8HUZ3cntJs4fLqaDyPRVcWhTHtY8dlbj0TuWtdP8Iw+A/bsn6U6TJagLUpUVwl//gY3ppR809UOev3zCQyQFnyLDiPV8VZcE+722bq75tTTcpuTPC2m7wRzICHpx2K9tbKv9XZDxOjo8ckVrQhF2qIk8wEOlrgZWo90ecHgJxxmbgcD8LBgBB6r/QZzWx2crRJ05tn0mKNZfXFJvvVsjXqlivQEhA7JXulLlxW6CfpHx7kXhUFFoE5FDk1VUzWFJupBeMHEwDMZF2PZ2lznY1xiaiHqo/+uZvfUKNdHNv7fEbInaa5+VMogV5+Tx7XPOV/BaXVrU3"
}

resource "aws_launch_configuration" "terramino" {
  name_prefix     = "learn-terraform-aws-asg-"
  image_id        = data.aws_ami.amazon-linux.id
  instance_type   = "t2.micro"
  user_data       = file("user-data.sh")
  security_groups = [aws_security_group.terramino_instance.id]
  key_name = aws_key_pair.deployer1.key_name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "terramino" {
  name                 = "terramino"
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.terramino.name
  vpc_zone_identifier  = module.vpc.public_subnets

  tag {
    key                 = "Name"
    value               = "HashiCorp Learn ASG - Terramino"
    propagate_at_launch = true
  }
}

resource "aws_lb" "terramino" {
  name               = "learn-asg-terramino-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terramino_lb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "terramino" {
  load_balancer_arn = aws_lb.terramino.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terramino.arn
  }
}

resource "aws_lb_target_group" "terramino" {
  name     = "learn-asg-terramino"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}


resource "aws_autoscaling_attachment" "terramino" {
  autoscaling_group_name = aws_autoscaling_group.terramino.id
  alb_target_group_arn   = aws_lb_target_group.terramino.arn
}

resource "aws_security_group" "terramino_instance" {
  name = "learn-asg-terramino-instance"
  ingress {
    from_port       = 22
    to_port         = 444
    protocol        = "tcp"
    security_groups = [aws_security_group.terramino_lb.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.terramino_lb.id]
  }

  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "terramino_lb" {
  name = "learn-asg-terramino-lb"
  ingress {
    from_port   = 22
    to_port     = 444
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}
