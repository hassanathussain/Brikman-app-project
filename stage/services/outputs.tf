output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.example.dns_name
}