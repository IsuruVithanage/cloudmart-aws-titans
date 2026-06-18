output "waf_arn" {
  description = "The ARN of the WAFv2 WebACL"
  value       = aws_wafv2_web_acl.cloudmart_waf.arn
}
