@echo off
set TERRAFORM_PATH=.\terraform.exe

echo "Destroying existing infrastructure..."
%TERRAFORM_PATH% destroy -auto-approve

echo "Planning the new infrastructure..."
%TERRAFORM_PATH% plan

echo "Applying the changes..."
%TERRAFORM_PATH% apply -auto-approve

echo "Refreshing Terraform state..."
%TERRAFORM_PATH% refresh

echo "Script completed."
