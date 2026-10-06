# AWS DevOps Agent

Terraform and Terragrunt configuration for deploying an AWS DevOps Agent Space, its IAM roles, and an AWS account association.

AWS DevOps Agent can inspect associated AWS resources and operational data to help investigate incidents, identify likely causes, and recommend improvements. An Agent Space is the access and operational boundary for that work. This configuration creates one or more Agent Spaces in `ca-central-1`, one per team, and associates the deployment account as a monitoring account for each of them.

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

The production account and cost centre are configured in `terragrunt/env/production/env_vars.hcl`. The shared `root.hcl` configures the `ca-central-1` provider and an encrypted S3 remote state backend with a DynamoDB table for state locking.

## Adding an Agent Space for a Team

Agent Spaces are defined in the `agent_spaces` map in `terragrunt/env/production/devops-agent/terragrunt.hcl`. To add one, add an entry and open a pull request:

```hcl
agent_spaces = {
  sre = { ... }

  platform = {
    name             = "CDS Platform agent space"
    description      = "AWS DevOps Agent Space for the platform team"
    application_name = "platform"
    tags             = { Team = "platform" } # optional
  }
}
```

Each entry gets its own agent IAM role, operator IAM role, Agent Space and monitoring-account association. The map key is a short team identifier made of lowercase letters, numbers and hyphens. Do not rename a key after it has been applied, because Terraform will destroy and recreate that team's Agent Space. Removing an entry destroys that team's Agent Space.

## Deploy

The CI definitions are `.github/workflows/tf-plan.yml` and `.github/workflows/tf_apply.tf`. 

The intended release sequence is:

1. Open a pull request with the Terragrunt changes and review the plan produced by the plan workflow. Pay particular attention to IAM permissions, role trust relationships, account ID, Region, and Agent Space settings.
2. Merge the reviewed change to `main` to trigger the apply workflow.
3. After a successful apply, verify the Agent Space, account association, and resource discovery in AWS.

To upgrade providers within the declared constraints, update the configuration as needed and review the resulting plan through CI. The AWS provider constraint `~> 6.0` permits 6.x releases, but not 7.x.

## Outputs

- `agent_spaces`: a map keyed by team identifier with each space's `id`, `arn`, `name`, `devops_agent_role_arn` and `operator_role_arn`.
- `monitoring_account_id`

Verify the Agent Space in the AWS DevOps Agent console and confirm that the account association and resource discovery are active.

## Security and Operations

- Keep Terraform state in the configured remote backend; state can contain sensitive infrastructure details.
- Keep IAM responsibilities separate: the agent role grants the service access to inspect resources, while the operator role controls access to the web application.
- Review AWS-managed policy changes and the generated Terraform plan before applying.
- Avoid logging credentials, tokens, personal information, payment details, or other sensitive data that the agent may process.
- Check current AWS documentation for supported Regions, service requirements, IAM policies, and resource schemas because AWS DevOps Agent and its Cloud Control resources can evolve.

Inspired by the AWS Build Center article "Deploying AWS DevOps Agent using Terraform" by Haytham Mostafa