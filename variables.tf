# VARIABLES

variable "region" {
  description = "aws region"
  type        = string
  default     = "eu-west-2"
}
variable "profile" {
  description = "aws user profile to utilise"
  type        = string
  default     = "capgemini"
}

variable "ip_name" {
    type = string                # instance profile name
    default = ""
}
variable "role_name" {           # role name
    type = string
    default = ""
}
variable "tag_name" {            # tag name key value
    type = string
    default = ""
}
variable "policy_arns" {         # list of arns to attach to the role
  description = "arns to add to ec2 role"
  type        = list(any)
  default     = [""]
}

variable "ec2_instance_size" {
    type = string
    default = "t2.micro"
}
variable "key_name" {
    type = string
}
variable "ec2_name" {
    type = string
}
variable "ec2_tags" {
  description = "resource tags"
  type        = map(any)
  default =   {}
}
variable "iam_inst_prof" {
  description = "IAM Instance profile name"
  type        = string
  default     = ""
}
variable "userdata" {
  description = "user_data template by type"
  type        = string
  default     = ""
}
variable "ec2_subnet" {
  description = "user_data template by type"
  type        = string
  default     = ""
}
variable "vpc_sg_ids" {
    description = "list of security groups"
    type = list
    default = [""]
}
variable "ami" {
  description = "AWS ami to use for instance"
  type        = string
  default     = ""
}

variable "instance_size" {
  description = "instance type mapped to role"
  type        = map(any)
  default = {
    prometheus = "t2.micro"
    proxy      = "t2.micro"
     }
}

