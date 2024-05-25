terraform {
  backend "s3" {
    bucket         = "terraform-s3-devops"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-s3"
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "azs" {
  type    = set(string)
  default = ["us-east-1a", "us-east-1b"]
}



resource "aws_vpc" "main" {
  cidr_block = "10.100.0.0/16"

  tags = {
    Name = "my-app-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.100.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "public_a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.100.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "public_b"
  }
}


resource "aws_subnet" "private_subnet_1" {
  cidr_block        = "10.100.0.0/24"
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_internet_gateway" "main-igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main-igw.id
}


resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_security_group" "docker_project_lb_sg" {
  name        = "docker-nginx-project-lb-sg"
  description = "allow incoming HTTP traffic only"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow incoming SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_lb" "docker_project_lb" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.docker_project_lb_sg.id}"]
  subnets            = ["${aws_subnet.public_a.id}", "${aws_subnet.public_b.id}"]
  tags = {
    Environment = "dev"
  }
}


resource "aws_lb_target_group" "docker_project_lb_tg" {
  name     = "docker-project-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_autoscaling_attachment" "demo_asg_attachment" {
  lb_target_group_arn    = aws_lb_target_group.docker_project_lb_tg.arn
  autoscaling_group_name = aws_autoscaling_group.docker_project_asg.id
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.docker_project_lb.arn
  port              = "80"
  protocol          = "HTTP"


  default_action {
    target_group_arn = aws_lb_target_group.docker_project_lb_tg.arn
    type             = "forward"
  }
}


resource "aws_launch_template" "ec2_launch_temp" {
  name_prefix   = "web-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [
    aws_security_group.docker_project_ec2.id,
    aws_security_group.allow_ssh.id,
  ]
  user_data = filebase64("${path.module}/server.sh")

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# creating autoscaling group
resource "aws_autoscaling_group" "docker_project_asg" {
  name = "docker-project-autoscaling-group"
  # launch_configuration = aws_launch_configuration.project.id
  vpc_zone_identifier = ["${aws_subnet.public_a.id}", "${aws_subnet.public_b.id}"]
  launch_template {
    id      = aws_launch_template.ec2_launch_temp.id
    version = "$Latest"
  }
  # target_group_arns = ["${aws_lb_target_group.docker_project_lb_tg.arn}"]

  desired_capacity = 2
  max_size         = 2
  min_size         = 1

  health_check_type = "ELB"
  tag {
    key                 = "Name"
    value               = "asg"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "docker_project_ec2" {
  name        = "docker-nginx-project-ec2"
  description = "allow incoming HTTP traffic only"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "asg_name" {
  value = aws_lb.docker_project_lb.dns_name
}

