init:
	terraform init

validate:
	terraform fmt -recursive
	terraform validate

plan: validate
	terraform plan

apply-only: plan
	terraform apply 

# Alternative apply target that auto-approves (use with caution, e.g., in CI/CD)
ap:
	terraform apply --auto-approve -no-color

des:
	@echo "Running pre-destroy cleanup script..."
	sh clean.sh
	terraform destroy --auto-approve -no-color

all: init apply
