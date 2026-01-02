# DB Data Disk — Snapshot, Restore & Reattach (Ops)

Purpose
- Explain how to restore a persistent zonal data disk from a snapshot and reattach it to a VM.
- Provide both `gcloud` and Terraform-friendly steps.

Prereqs
- You have IAM permissions to manage snapshots/disks and to attach disks (Compute Admin or equivalent, and `iap.tunnelInstances.accessViaIAP` is not required for disk ops).
- Know the `PROJECT`, `ZONE` (e.g., us-central1-a) and the instance name (`edgequake-db-vm`).

Important notes
- The module creates a protected data disk by default (lifecycle.prevent_destroy = true). To remove protection intentionally set `data_disk_prevent_destroy = false` and apply.
- A daily snapshot schedule (resource policy) is created by default; retention is controlled by `snapshot_retention_days` (default: 3).

Common operations

1) List resource policies (verify schedule)

  gcloud compute resource-policies list --regions=${REGION}
  gcloud compute resource-policies describe ${POLICY_NAME} --region=${REGION}

2) List snapshots created by the policy

  gcloud compute snapshots list --filter='name~"^edgequake.*"' --sort-by=~creationTimestamp

3) Create a new disk from a snapshot (restore)

  # Pick a snapshot name from the previous command, then:
  gcloud compute disks create edgequake-data-disk-restore-2026-01-02 \
    --project=${PROJECT} --zone=${ZONE} --source-snapshot=${SNAPSHOT_NAME} --type=pd-standard --size=50GB

4) Attach the restored disk to an instance (manual attach)

  # Stop PostgreSQL / gracefully flush before detaching if this is a live restore.
  gcloud compute instances attach-disk ${INSTANCE_NAME} --disk=edgequake-data-disk-restore-2026-01-02 --zone=${ZONE} --device-name=data-disk

  # On the VM, mount and verify (if not auto-mounted by startup scripts):
  sudo mkdir -p /mnt/data
  sudo mount /dev/disk/by-id/google-data-disk /mnt/data
  sudo chown -R postgres:postgres /mnt/data

  # If needed, create fstab entry (careful with device names and UUIDs):
  echo '/dev/disk/by-id/google-data-disk /mnt/data ext4 defaults 0 2' | sudo tee -a /etc/fstab

5) Use Terraform to reattach / import disk (preferred for tracked infra)

  # Option A: Import an existing restored disk into Terraform and set module var
  # 1) Import disk resource (example):
  terraform import module.compute.google_compute_disk.data_disk_protected[0] projects/${PROJECT}/zones/${ZONE}/disks/edgequake-data-disk-restore-2026-01-02

  # 2) Set variables in terraform.tfvars (alternatively use existing_data_disk_self_link):
  existing_data_disk_self_link = "projects/${PROJECT}/zones/${ZONE}/disks/edgequake-data-disk-restore-2026-01-02"

  # 3) terraform plan && terraform apply to attach & ensure module state knows about the disk.

  # Option B: Use `existing_data_disk_self_link` module input (no import) and run terraform apply.

6) Recreate a VM and reattach (if VM was destroyed)

  - If the module is configured to attach the disk via `existing_data_disk_self_link` or the created disk resource, replacing the VM with Terraform will cause the new instance to attach the existing disk automatically.

7) Remove disk protection (if you intentionally want to destroy the disk)

  # Edit terraform.tfvars: set data_disk_prevent_destroy = false
  terraform plan -out=tfplan
  terraform apply tfplan

8) Troubleshooting

- Device not present on VM after attach: check zone mismatch and `gcloud compute instances describe ${INSTANCE_NAME} --zone=${ZONE}` for attached disks.
- Mount fails: run `sudo lsblk` and examine `/dev/disk/by-id/` entries; ensure correct device used in fstab.
- Snapshot not found: ensure you're in the same project and describe the resource policy to list chain snapshots.

References
- Google Cloud: Snapshot Schedules & Resource Policies
  https://cloud.google.com/compute/docs/disks/snapshots/snapshot-schedules
- Terraform resources:
  - google_compute_resource_policy
  - google_compute_disk_resource_policy_attachment
  - google_compute_disk

---
Quick checklist
- [ ] Verify `edgequake-daily-snap-policy` exists and retention is correct
- [ ] Know how to restore and import a disk or set `existing_data_disk_self_link` if recovering

