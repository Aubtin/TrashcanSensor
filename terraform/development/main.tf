# START: TERRAFORM SETUP
terraform {
  backend "s3" {
    bucket = "aubtin-terraform-states"
    # --------- UPDATE THIS ---------
    key = "TrashcanSensor-development/terraform.tfstate"
    region = "us-west-2"
    encrypt = true
    dynamodb_table = "TerraformStateManager"
  }
}
# END: TERRAFORM SETUP

provider "aws" {
  version = "~> 2.70"

  region = var.aws_region
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    program = var.service_name
  }
}

resource "aws_subnet" "subnetPublic1" {
  vpc_id = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  cidr_block = "10.0.1.0/24"

  tags = {
    program = var.service_name
  }
}

resource "aws_internet_gateway" "internetGateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    program = var.service_name
  }
}

resource "aws_route_table" "publicSubnetRouteTable" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internetGateway.id
  }

  tags = {
    program = var.service_name
  }
}

resource "aws_route_table_association" "publicSubnetRouteAssociation" {
  route_table_id = aws_route_table.publicSubnetRouteTable.id
  subnet_id = aws_subnet.subnetPublic1.id
}

resource "aws_s3_bucket" "TrashcanS3Bucket" {
  bucket = "${lower(var.service_name)}-${var.stage}-storage"
  acl = "private"

  tags = {
    program = var.service_name
  }
}

data "aws_ami" "amzn2-ami-hvm" {
  filter {
    name = "image-id"
    values = ["ami-07a0da1997b55b23e"]
  }

  owners = ["amazon"]
}

resource "aws_network_interface" "eni" {
  subnet_id = aws_subnet.subnetPublic1.id
  description = "Network interface for ${var.service_name}."
  security_groups = [aws_security_group.TrashcanSensorSecurityGroup.id]

  tags = {
    program = var.service_name
  }
}

resource "aws_eip" "ip" {
  network_interface = aws_network_interface.eni.id
  vpc = true

  tags = {
    program = var.service_name
  }
}

resource "aws_launch_template" "TrashcanAPI" {
  name = "${var.service_name}-api"
  image_id = data.aws_ami.amzn2-ami-hvm.id
  instance_type = "t1.micro"
  key_name = "Sentry"
  update_default_version = true

  network_interfaces {
    network_interface_id = aws_network_interface.eni.id
  }


  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 8
      volume_type = "standard"
      delete_on_termination = "true"
      snapshot_id = data.aws_ami.amzn2-ami-hvm.root_snapshot_id
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.TrashcanSensorInstanceProfile.arn
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      program = var.service_name
    }
  }

  instance_market_options {
    market_type = "spot"

    spot_options {
      spot_instance_type = "persistent"
      instance_interruption_behavior = "stop"
    }
  }

  credit_specification {
    cpu_credits = "standard"
  }

  user_data = base64encode(templatefile("../user_data/API",
              {
                bucket_domain=aws_s3_bucket.TrashcanS3Bucket.bucket
                db_table_name=aws_dynamodb_table.TrashcanSensorDynamoBTable.name
              }))
}

resource "aws_security_group" "TrashcanSensorSecurityGroup" {
  name = "${var.service_name}SecurityGroup"
  description = "Security group for Trashcan Sensor."
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 80
    protocol = "TCP"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
      program = var.service_name
    }
}

resource "aws_iam_instance_profile" "TrashcanSensorInstanceProfile" {
  name = "${var.service_name}-InstanceProfile-${var.stage}"
  role = aws_iam_role.TrashcanSensorIAMRole.name
}

resource "aws_iam_role" "TrashcanSensorIAMRole" {
  name = "trashcansensor-ec2-role-${var.stage}"

  assume_role_policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    program = var.service_name
  }
}

resource "aws_iam_role_policy" "TrashcanSensorPolicy" {
  name = "trashcansensor-role-${var.stage}"
  role = aws_iam_role.TrashcanSensorIAMRole.id

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:ListObjects",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.TrashcanS3Bucket.arn}",
        "${aws_s3_bucket.TrashcanS3Bucket.arn}/*"
      ],
      "Effect": "Allow"
    },
    {
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "${aws_dynamodb_table.TrashcanSensorDynamoBTable.arn}"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_dynamodb_table" "TrashcanSensorDynamoBTable" {
  hash_key = "pk"
  range_key = "sk"

  name = "${var.service_name}-${var.stage}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }
}