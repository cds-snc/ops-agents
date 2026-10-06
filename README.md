# AWS DevOps Agent

Terraform and Terragrunt configuration for deploying an AWS DevOps Agent Space, its IAM roles, and an AWS account association.

AWS DevOps Agent can inspect associated AWS resources and operational data to help investigate incidents, identify likely causes, and recommend improvements. An Agent Space is the access and operational boundary for that work. This configuration creates one Agent Space in `ca-central-1` and associates the deployment account as a monitoring account.

## Repository Layout

```text
terragrunt/
	aws/devops-agent/                 # Reusable Terraform module
	env/
		common/                         # Shared provider and variables
		production/
			env_vars.hcl                  # Production account and cost centre
			devops-agent/terragrunt.hcl   # Production Terragrunt unit
.github/                            # CI configuration
```

The Terraform module creates the DevOps Agent IAM role, operator application IAM role, their policies, a short IAM propagation delay, the Agent Space, and the monitoring-account association.

## Prerequisites

- Terraform 1.16.5 and Terragrunt 1.1.0, matching the versions configured for CI.
- AWS CLI credentials for the target account. Confirm the active identity with `aws sts get-caller-identity` before planning or applying.
- AWS permissions to create the DevOps Agent resources and association, IAM roles and policies, and any required service-linked roles. The deployment identity must be allowed to pass the roles to AWS DevOps Agent.
- The remote Terraform state S3 bucket and DynamoDB lock table configured by `terragrunt/env/root.hcl` must already exist and be accessible.
- AWS DevOps Agent must be available in the configured Region. The current Terragrunt configuration sets `ca-central-1`.

Use temporary credentials or an assumed role for production. Do not put access keys, secrets, or sensitive operational data in Terraform variables, tags, or logs.

## Configure Before Deployment

The production account, cost centre, Agent Space name, description, and application name are configured in `terragrunt/env/production/env_vars.hcl`. That file currently declares `inputs` twice; combine the values into one block before using the configuration. The shared `root.hcl` configures the `ca-central-1` provider and an encrypted S3 remote state backend with a DynamoDB table for state locking.

The module requires `agent_space_name`, `agent_space_description`, and `application_name`. Although these values are present in `env_vars.hcl`, `root.hcl` currently forwards only the shared account and tagging inputs to Terraform. Add mappings for the three required values to the `inputs` block in `terragrunt/env/root.hcl` (or configure and merge them at the production unit) before planning. For example:

```hcl
inputs = {
	agent_space_name        = local.vars.inputs.agent_space_name
	agent_space_description = local.vars.inputs.agent_space_description
	application_name        = local.vars.inputs.application_name
}
```

`terragrunt/env/production/devops-agent/terragrunt.hcl` points to the existing `terragrunt/aws/devops-agent` module and includes the shared root configuration. The production input values must still be forwarded to the module as described above. The module also uses the `awscc` and `time` providers, while `terragrunt/env/common/provider.tf` only constrains `hashicorp/aws` to `~> 6.0`; add constraints and commit the lock file if reproducible provider selection is required.

## Deploy

The CI definitions are `.github/workflows/tf-plan.yml` and `.github/workflows/tf_apply.tf`. 

The intended release sequence is:

1. Open a pull request with the Terragrunt changes and review the plan produced by the plan workflow. Pay particular attention to IAM permissions, role trust relationships, account ID, Region, and Agent Space settings.
2. Merge the reviewed change to `main` to trigger the apply workflow.
3. After a successful apply, verify the Agent Space, account association, and resource discovery in AWS.

To upgrade providers within the declared constraints, update the configuration as needed and review the resulting plan through CI. The AWS provider constraint `~> 6.0` permits 6.x releases, but not 7.x.

## Outputs

The module exposes these Terraform outputs:

- `agent_space_id` and `agent_space_arn`
- `agent_space_name`
- `devops_agent_role_arn`
- `operator_role_arn`
- `monitoring_account_id`


Verify the Agent Space in the AWS DevOps Agent console and confirm that the account association and resource discovery are active.

## Security and Operations

- Keep Terraform state in the configured remote backend; state can contain sensitive infrastructure details.
- Keep IAM responsibilities separate: the agent role grants the service access to inspect resources, while the operator role controls access to the web application.
- Review AWS-managed policy changes and the generated Terraform plan before applying.
- Avoid logging credentials, tokens, personal information, payment details, or other sensitive data that the agent may process.
- Check current AWS documentation for supported Regions, service requirements, IAM policies, and resource schemas because AWS DevOps Agent and its Cloud Control resources can evolve.

Inspired by the AWS Build Center article "Deploying AWS DevOps Agent using Terraform" by Haytham Mostafa