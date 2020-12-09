# START: TERRAFORM SETUP
terraform {
  backend "s3" {
    bucket = "aubtin-terraform-states"
    # --------- UPDATE THIS ---------
    key = "TrashcanSensor-production/terraform.tfstate"
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

resource "aws_s3_bucket_policy" "TrashcanS3BucketPolicy" {
  bucket = aws_s3_bucket.TrashcanS3Bucket.bucket
  policy = <<-EOF
{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "2",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_cloudfront_origin_access_identity.originIdentity.iam_arn}"
            },
            "Action": "s3:GetObject",
            "Resource": "${aws_s3_bucket.TrashcanS3Bucket.arn}/dashboard/*"
        }
    ]
}
EOF
}

resource "aws_s3_bucket_object" "dashboard_directory" {
  bucket = aws_s3_bucket.TrashcanS3Bucket.bucket
  key = "dashboard/"

}

data "aws_ami" "ubuntu-2020-hvm-ami" {
  filter {
    name = "image-id"
    values = ["ami-07dd19a7900a1f049"]
  }

  owners = ["099720109477"]
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
  image_id = data.aws_ami.ubuntu-2020-hvm-ami.id
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
      snapshot_id = data.aws_ami.ubuntu-2020-hvm-ami.root_snapshot_id
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

    ingress {
    from_port = 22
    protocol = "TCP"
    to_port = 22
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

  tags = {
    program = var.service_name
  }
}

resource "aws_autoscaling_group" "apiServer" {
  availability_zones = [aws_subnet.subnetPublic1.availability_zone]
  desired_capacity = 1
  max_size = 1
  min_size = 1

  launch_template {
    id = aws_launch_template.TrashcanAPI.id
    version = "$Latest"
  }
}

locals {
  s3_origin_id = "trashcanSensorS3Origin"
}

resource "aws_cloudfront_origin_access_identity" "originIdentity" {
  comment = "${var.service_name} Origin Identity"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.TrashcanS3Bucket.bucket_regional_domain_name
    origin_id = local.s3_origin_id
    origin_path = "/dashboard"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.originIdentity.cloudfront_access_identity_path
    }
  }

  custom_error_response {
    error_code = 404
    response_code = 200
    response_page_path = "/"
    error_caching_min_ttl = 5
  }

    custom_error_response {
    error_code = 403
    response_code = 200
    response_page_path = "/"
    error_caching_min_ttl = 5
  }

  enabled = true
  is_ipv6_enabled = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT"]
    cached_methods = [
      "GET",
      "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }

    # HTTP only works in this situation. Can't mix HTTP and HTTPS (IP vs CloudFront certificate).
    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    program = var.service_name
  }
}
