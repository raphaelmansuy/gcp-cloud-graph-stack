output "vpc_name" {
  description = "VPC network name"
  value       = module.vpc.vpc_name
}

output "subnet_name" {
  description = "Subnet name"
  value       = module.vpc.subnet_name
}

output "vm_instance_name" {
  description = "Compute Engine VM instance name"
  value       = module.compute.instance_name
}

output "vm_private_ip" {
  description = "Compute Engine VM private IP"
  value       = module.compute.vm_private_ip
}

output "vm_external_ip" {
  description = "Compute Engine VM external IP (if exists)"
  value       = module.compute.vm_external_ip
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository URL (docker registry)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_images.repository_id}"
}

output "nextjs_service_url" {
  description = "Next.js Cloud Run service URL"
  value       = module.cloud_run_nextjs.service_uri
}

output "rust_api_service_url" {
  description = "Rust API Cloud Run service URL"
  value       = module.cloud_run_rust_api.service_uri
}

output "cloud_run_service_account" {
  description = "Cloud Run service account email"
  value       = google_service_account.cloud_run_sa.email
}

output "vpc_connector_name" {
  description = "VPC Connector name (if not using Direct VPC egress)"
  value       = !var.enable_direct_vpc_egress ? module.vpc.vpc_connector_name : null
}

output "deployment_instructions" {
  description = "Instructions for deploying the application"
  value       = <<-EOT
    Deployment Instructions:

    1. Initialize Terraform:
       terraform init

    2. Review the plan:
       terraform plan -out=tfplan

    3. Apply the configuration:
       terraform apply tfplan

    4. Next.js Frontend:
       - Build: docker build -t nextjs:latest -f dockerfiles/Dockerfile.nextjs .
       - Tag: docker tag nextjs:latest ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_images.repository_id}/nextjs:latest
       - Push: docker push ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_images.repository_id}/nextjs:latest
       - Update Terraform variable: nextjs_image_url
       - Apply: terraform apply

    5. Rust API:
       - Build: docker build -t rust-api:latest -f dockerfiles/Dockerfile.rust .
       - Tag: docker tag rust-api:latest ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_images.repository_id}/rust-api:latest
       - Push: docker push ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_images.repository_id}/rust-api:latest
       - Update Terraform variable: rust_api_image_url
       - Apply: terraform apply

    6. SSH to VM for database setup:
       gcloud compute ssh ${module.compute.instance_name} --region=${var.region}

    7. Verify Cloud Run services:
       gcloud run services list --region=${var.region} --project=${var.project_id}
  EOT
}
