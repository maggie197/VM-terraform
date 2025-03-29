# Terraform CI/CD pipeline that creates Virtual Machine (VM) on Google Cloud using GitHub Actions

## 1. Create a Terraform configuration file

Create a directory for your Terraform project and inside it, create a main.tf file. This file will define your resources.

```
    provider "google" {
    credentials = file("terraform-key.json")
    project = "name-project"    # project name
    region  = "region"      # add region  
    zone    = "zone"    # add zone
    }

    resource "google_compute_instance" "opencart_vm" {
    name         = "opencart-vm"
    machine_type = "e2-medium"
    zone         = "zone"   # add zone

    tags = ["http-server", "https-server", "ssh-server"]

    boot_disk {
        initialize_params {
        image = "ubuntu-os-cloud/ubuntu-2204-lts"  # Use Ubuntu 22.04 LTS
        size  = 20
        type  = "pd-balanced"
        }
    }

    network_interface {
        network = "default"
        access_config {}  
    }

    metadata = {
        enable-osconfig = "TRUE"
    }

    service_account {
        scopes = ["cloud-platform"]
    }
    }

    resource "null_resource" "delete_ssh_firewall" {
    provisioner "local-exec" {
        command = "gcloud compute firewall-rules delete allow-ssh --quiet"
    }

    triggers = {
        always_run = "${timestamp()}"
    }
    }

    resource "google_compute_firewall" "allow_ssh" {
    depends_on = [null_resource.delete_ssh_firewall]  # Ensures the delete command runs first

    name    = "allow-ssh"
    network = "default"

    allow {
        protocol = "tcp"
        ports    = ["22"]
    }

    source_ranges = ["0.0.0.0/0"]

    lifecycle {
        ignore_changes = [name]
    }
    }

```

## 2. Add GitHub Actions Pipeline:

Add .github/workflows/terraform-pipeline.yml

```
name: Terraform VM Deployment

on:
  push:
    branches:
      - main

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4

    - name: Set up Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.6.0

    - name: Authenticate with GCP
      run: |
        echo '${{ secrets.GCP_CREDENTIALS }}' | base64 --decode > terraform-key.json
        gcloud auth activate-service-account --key-file=terraform-key.json
        gcloud config set project ${{ secrets.GCP_PROJECT_ID }}
        gcloud config set compute/zone ${{ secrets.GCP_ZONE }}

    - name: Initialize Terraform
      run: terraform init

    - name: Validate Terraform
      run: terraform validate

    - name: Plan Terraform
      run: terraform plan

    - name: Apply Terraform
      run: terraform apply -auto-approve

```

## 3. Create Service Account and its key 

1. Go to Google Cloud Console:
2. Log in with your Google account.
3. Select Your Project:
4. Navigate to IAM & Admin and click on Service Accounts
5. Create a Service Account and then click on the Service Account name.
6. Go to the “Keys” Tab: Click “Add Key” → “Create new key”. Select JSON as the key type.
7. Download the Key


## 4.  GitHub Secrets Setup

Set these secrets in your GitHub repository:

* GCP_CREDENTIALS → Base64 encoded service account JSON key.
* GCP_PROJECT_ID → your-project-ID
* GCP_ZONE → your-vm-zone

To encode the key:

```
base64 terraform-service-account.json > terraform-key-base64.txt
```
Copy and paste the content of terraform-key-base64.txt to the GCP_CREDENTIALS secret.

## 5. Git Commands to Push

```
# Initialize GitHub repo
git init
git remote add origin https://github.com/USERNAME/terraform-vm.git

git add .
git commit -m "Add Terraform VM pipeline"
git push -u origin main

```

## 6. To Re-running a Workflow (Optional)

* Go to the Actions tab of your GitHub repository.

* Find the workflow run you want to re-run.

* Click on it, and you'll see a Re-run jobs or Re-run failed jobs button.

# Create a Terraform pipeline that deletes a virtual machine in Google Cloud (Optional)

1. Delete the VM Pipeline

This pipeline will delete the virtual machine by running the Terraform destroy command. It can also be manually triggered using workflow_dispatch.

```
# .github/workflows/delete-vm.yml

name: Destroy Google Cloud VM

on:
  workflow_dispatch:  # Trigger manually

jobs:
  destroy-vm:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
        
      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v1
        with:
          terraform_version: 1.4.0

      # Authenticate with GCP using Base64 encoded secret
      - name: Authenticate with GCP
        run: |
          echo '${{ secrets.GCP_CREDENTIALS }}' | base64 --decode > terraform-key.json
          gcloud auth activate-service-account --key-file=terraform-key.json
          gcloud config set project ${{ secrets.GCP_PROJECT_ID }}
          gcloud config set compute/zone ${{ secrets.GCP_ZONE }}


      - name: Initialize Terraform
        run: terraform init -input=false

            # Import the existing VM into Terraform state
      - name: Import Existing VM
        run: |
          terraform import google_compute_instance.instancevm projects/${{ secrets.GCP_PROJECT_ID }}/zones/${{ secrets.GCP_ZONE }}/instances/instancevm || echo "VM already imported or not found, skipping."

      - name: Plan to Destroy VM
        run: terraform plan -destroy -out=tfplan

      - name: Apply and Destroy VM
        run: terraform apply -auto-approve tfplan

```

2. Git push and commit changes