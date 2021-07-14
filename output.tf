output "iam_instance_profile_name" {
    value = aws_iam_instance_profile.ec2_profile.name
}

output "public_ip" {
  value = join("", aws_instance.instance[*].public_ip)
}

output "private_ip" {
    value = join("", aws_instance.instance[*].private_ip)
}