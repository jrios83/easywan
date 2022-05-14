terraform {
 
  backend "s3" {
    bucket         = "tf-state-jrios"
    key            = "devops/sdwan/lisp/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = {
      Service = "msmr"
    }
  }
}

resource "aws_instance" "msmr-example" {
  ami             = "ami-0892d3c7ee96c0bf7" # Ubuntu 20.04 LTS // us-east-1
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.allow_lisp_ports.name]
  key_name = "msmrKey"
}

data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnet_ids" "default_subnet" {
  vpc_id = data.aws_vpc.default_vpc.id
}

resource "aws_security_group" "allow_lisp_ports" {
    name = "security-group.msmr"
    description = "open ports for msmr functionality"

    ingress{
        from_port = 4342
        to_port = 4342
        protocol = "udp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress{
        from_port = 4341
        to_port = 4341
        protocol = "udp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress{
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress{
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "msmrKey" {
  key_name   = "msmrKey"      
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" { 
    command = "rm -rf ~/.ssh/msmrKey.pem && echo '${tls_private_key.pk.private_key_pem}' > ~/.ssh/msmrKey.pem && chmod 400 ~/.ssh/msmrKey.pem"
  }
}

output "ec2_global_ip" {
  value = ["${aws_instance.msmr-example.*.public_ip}"]
}

output "ec2_private_ip" {
  value = ["${aws_instance.msmr-example.*.private_ip}"]
}

output "ec2_public_dns" {
  value = ["${aws_instance.msmr-example.*.public_dns}"]
}

/*resource "aws_route53_zone" "primary" {
  name = "orsisperu.com"
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "msmr"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.msmr-example.public_ip]
  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}*/