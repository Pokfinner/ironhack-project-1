# Terraform Infrastructure Setup

This project uses Terraform to create the AWS infrastructure for the application.

## Infrastructure Overview

The current infrastructure includes:

| Resource | Details |
|----------|---------|
| VPC      | 1 VPC network |
| Subnets  | 2 subnets: 1 public, 1 private |
| Gateway  | Network gateway |
| Security Groups | Security groups for the EC2 instances |
| EC2 Instances | 3 instances running Amazon Linux |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- AWS credentials configured (for example with `aws configure`)
- All required variables and fields filled in before running (see below)

## Steps to Create the Infrastructure

Run the commands below from the directory that contains the Terraform files.

### 1. Initialize Terraform

Downloads the required providers and sets up the working directory.

terraform init

### 2. Format the code

Formats the configuration files to the standard style.

terraform fmt

### 3. Validate the configuration

Checks the configuration for syntax errors and internal consistency.

terraform validate

### 4. Review the plan

Shows what Terraform will create, change, or destroy. Review it before applying.

terraform plan


### 5. Apply the changes

Creates the infrastructure.


terraform apply


Terraform asks for confirmation before making changes. Type `yes` to proceed.

## Important

Make sure all fields are properly filled in before you run `terraform plan` and `terraform apply`. This includes variables such as the region, CIDR blocks, AMI ID, instance type, and key pair name, depending on what your configuration defines.

## Destroying the Infrastructure

To remove everything this project created:

terraform destroy

## Additional point Review the list of resources carefully before confirming, because this deletes them.
Include a .gitignore entry for Terraform state and sensitive variable files, such as .terraform/, *.tfstate, *.tfstate.*, and *.tfvars (while retaining any non-sensitive example files such as terraform.tfvars.example).