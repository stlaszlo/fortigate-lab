output "guacamole_private_ip" {
  description = "Private IP of the Guacamole access gateway."
  value       = module.guacamole.private_ip
}

output "guacamole_url" {
  description = "Public training portal hostname."
  value       = "https://training.axionsec.ai"
}
