provider "aws" {
  region  = var.region
  profile = var.profile
}

module "vpc" {
  source                   = "terraform-aws-modules/vpc/aws"
  version                  = "2.77.0"
  cidr                     = "10.0.0.0/16"
  azs                      = data.aws_availability_zones.available.names
  private_subnets          = ["10.0.2.0/28", "10.0.4.0/28"]
  public_subnets           = ["10.0.1.0/28"]
  enable_dns_hostnames     = true
  enable_nat_gateway       = true
  single_nat_gateway       = true
  public_subnet_tags = {
    Name = "${var.env_prefix}-public"
  }
  tags = var.tags
  vpc_tags = {
    Name = "${var.env_prefix}-VPC"
  }
  private_subnet_tags = {
    Name = "${var.env_prefix}-private"
  }
  igw_tags = {
    Name = "${var.env_prefix}-igw"
  }
   nat_gateway_tags = {
    Name = "${var.env_prefix}-natgw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"         # Return all available az in the region
}

variable "tags" {
  description = "resource tags"
  type        = map(any)
  default = {
    CostCentre : "common"
    Project : "infra"
    Description : "demo"
    Owner : "dan.henderson"
  }
}
variable "env_prefix" {
  description = "prefix for naming"
  type        = string
  default     = "demo"
}

module "security-group-prometheus" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "3.18.0"
  name = "SGAllowPrometheus"                         # Name of the Security group
  vpc_id = module.vpc.vpc_id                         # VPC Id using the value from the vpc module
  tags = merge(                                      # Tagging - add the tag variables and merge with name
    var.tags, {
      Name = "SgAllowPrometheus"
  })
  ingress_with_cidr_blocks = [                       # SG custom ingress rules for Prometheus server which is in 
    {                                                # a Private subnet
      from_port   = 9090
      to_port     = 9100
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 9182
      to_port     = 9182
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },]
    egress_with_cidr_blocks = [                      # SG Egress rules for Prometheus server
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

module "security-group-proxy" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "3.18.0"
  name = "SgAllowProxy"                             # Name of the Security group
  vpc_id = module.vpc.vpc_id                        # VPC Id using the value from the vpc module
  tags = merge(                                     # Tagging - add the tag variables and merge with name
    var.tags, {
      Name = "SgAllowProxy"
  })
  ingress_cidr_blocks = ["0.0.0.0/0"]               # SG predefined ingress rules for Proxy server which is in 
  ingress_rules = ["http-80-tcp"]                   # a public subnet
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

terraform {
    required_version = ">=0.14.8"
}
                                   
resource "aws_iam_role" "demo-ssm-role" {               # Define our resource role for systems manager
  name = var.role_name                                  # the role name from a variables
  assume_role_policy = jsonencode({                     # use jsonencode to format the role policy to a string
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = merge(
    var.tags, {
      Name = var.tag_name
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = var.ip_name                                      # variable to define the instance profile name
  role = aws_iam_role.demo-ssm-role.name                  # which role is associated with the instance profile
}

resource "aws_iam_role_policy_attachment" "ssm-attach" {  # define which existing policies to attach to the the role
  role       = aws_iam_role.demo-ssm-role.name            # name of the role
  count      = length(var.policy_arns)                    # loop through each policy arn defined in the variable
  policy_arn = var.policy_arns[count.index]
}

module "instance_profile" {
  source      = "./modules/instance_profile"                             # where we created our configuration
  ip_name     = "demo_ec2_profile"                                       # instance profile name
  role_name   = "demo_ssm_role"                                          # role name
  policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"] # list of policy arn to attach
  tag_name    = "demo-ec2-ssm-policy"                                    # the tag key name value
  tags        = var.tags                                                 # pass the root module tag variable values
}

terraform {
    required_version = ">=0.14.8"
}

resource "aws_instance" "instance" {                                    # aws_instance resource type
    ami                    = var.ami                                    # the ami id
    iam_instance_profile   = var.iam_inst_prof                          # the instance profile/role to attach
    instance_type          = var.ec2_instance_size                      # the instance size
    subnet_id              = var.ec2_subnet                             # which subnet to deploy into
    vpc_security_group_ids = var.vpc_sg_ids                             # security groups
    key_name               = var.key_name                               # ssh key
    tags                   = merge(var.ec2_tags,{Name = var.ec2_name})  # tags
    user_data              = var.userdata                               # userdata to apply
}

module "proxy_server" {
  source            = "./modules/instances"
  count             = 1
  ec2_name          = "${"core-proxy"}${format("%02d",count.index+1)}"
  key_name          = var.key_name                                     # we will need to define this in our root variables.tf
  ec2_subnet        = module.vpc.public_subnets[0]                     # retrieve the public sn from the vpc module
  vpc_sg_ids        = [module.security-group-prometheus.this_security_group_id, module.security-group-proxy.this_security_group_id]                                          # retrieve the security group id from the module
  ami               = data.aws_ami.aws-linux2.id                       # we will need a data source to get the latest ami
  iam_inst_prof     = module.instance_profile.iam_instance_profile_name# profile name from our module
  ec2_instance_size = var.instance_size["proxy"]                       # instance size map variable. Need to define 
  ec2_tags          = var.tags
  userdata          = templatefile("./templates/proxy.tpl",{proxy_server = ("core-proxy${format("%02d",count.index+1)}"), prom_server = module.prometheus_server[count.index].private_ip})
}

data "aws_ami" "aws-linux2" {
  most_recent = true                                            # Retrieve the latest ami
  owners      = ["amazon"]                                      # It must be owned by amazon
  filter {                                                      # add some filters
    name   = "name"                                     
    values = ["amzn2-ami-hvm*"]                                 # The name must begin with amzn2-ami-hvm
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]                                            # The root volume must be of type ebs
  }
}

module "prometheus_server" {
  source            = "./modules/instances"
  count             = 1
  ec2_name          = "${"core-prom"}${format("%02d",count.index+1)}"
  key_name          = var.key_name
  ec2_subnet        = module.vpc.private_subnets[0]
  vpc_sg_ids        = [module.security-group-prometheus.this_security_group_id, module.security-group-proxy.this_security_group_id]
  ami               = data.aws_ami.aws-linux2.id
  iam_inst_prof     = module.instance_profile.iam_instance_profile_name
  ec2_instance_size = var.instance_size["prometheus"]
  ec2_tags          = var.tags
  userdata          = templatefile("./templates/prometheus.tpl", {prometheus_server = ("core-prom${format("%02d",count.index+1)}")})
}

