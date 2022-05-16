output "lb_endpoint" {
  value = "https://${aws_lb.terramino.dns_name}"
}

output "application_endpoint" {
  value = "https://${aws_lb.terramino.dns_name}/index.php"
}

output "asg_name" {
  value = aws_autoscaling_group.terramino.name
}

output "keyname" {
  value = aws_key_pair.deployer1.key_name
}
