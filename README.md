# AWS DevOps Agent

Terraform and Terragrunt configuration for deploying AWS DevOps Agent Spaces, their IAM roles, and their AWS account associations.

AWS DevOps Agent can inspect associated AWS resources and operational data to help investigate incidents, identify likely causes, and recommend improvements. An Agent Space is the access and operational boundary for that work. This configuration creates one or more Agent Spaces in `ca-central-1`, one per team, and associates the deployment account as a monitoring account for each of them. Each space can also be associated with secondary accounts.

## Repository Layout

```text
terragrunt/
	aws/devops-agent/                 # Reusable Terraform module
	env/
		common/                         # Shared provider and variables
		production/
			env_vars.hcl                  # Production account and cost centre
			devops-agent/
				terragrunt.hcl              # Production Terragrunt unit and Identity Center instance ARN
				agent-spaces/               # One YAML file per team Agent Space
.github/                            # CI configuration
```

The Terraform module creates the DevOps Agent IAM role, operator application IAM role, their policies, a short IAM propagation delay, the Agent Space, the monitoring-account association, and an association for each listed secondary account. For spaces that opt in, it also connects the Agent Space web app to IAM Identity Center.

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

Each Agent Space is defined by one YAML file in `terragrunt/env/production/devops-agent/agent-spaces/`. The file name without `.yaml` is the team key. To add a team:

1. Copy `agent-spaces/_template.yaml.example` to `agent-spaces/<team-key>.yaml`, for example `platform.yaml`.
2. Fill in the values and open a pull request.
3. Review the plan. It should only show new resources for the new team.
4. Merge to `main` to create the Agent Space.

```yaml
# agent-spaces/platform.yaml
name: CDS Platform agent space
description: AWS DevOps Agent Space for the platform team
application_name: platform
tags:                          # optional
  Team: platform
identity_center_enabled: true  # optional, defaults to false
source_accounts:               # optional, secondary account IDs
  - "111122223333"
```

Each file gets its own agent IAM role, operator IAM role, Agent Space, monitoring-account association, and one association per listed secondary account. The team key must be lowercase letters, numbers and hyphens, and each `name` must be unique. Do not rename a file after it has been applied, because Terraform will destroy and recreate that team's Agent Space. Deleting a file destroys that team's Agent Space.

## User Access with IAM Identity Center

Team members sign in to an Agent Space's web app through IAM Identity Center. The setup is split across two repositories:

- **This repository** connects the Agent Space to Identity Center. AWS DevOps Agent then creates an Identity Center application for the space. This matches choosing Connect on the space's Access tab in the console.
- **The landing zone repository** creates the Identity Center groups and assigns them to that application. Adding or removing a person is done there, or in the identity provider that syncs into Identity Center.

To connect a space, set this in its YAML file:

```yaml
identity_center_enabled: true
```

After the apply, take the space's `identity_center_application_arn` from the `agent_spaces` output and pass it to the landing zone repository. The group assignments can only be created once the application exists, so apply this repository first.

The output can stay null on the apply that connects Identity Center, because AWS may not return the application ARN yet. If it does, find the ARN in the IAM Identity Center console of the management account under Applications, or run the next plan or apply to refresh it.

IAM sign-in stays enabled for 30-minute administrator sessions from the AWS console.

Identity Center sign-in uses the same operator role as IAM sign-in. Its trust policy allows `sts:SetContext`, limited to Identity Center as the context provider, so the web app can attach the signed-in user's identity to the session. Without it, Identity Center users see "You are not authorized to view this Agent Space" while IAM admin access still works.

Set the Identity Center organization instance ARN as `identity_center_instance_arn` in `terragrunt/env/production/devops-agent/terragrunt.hcl`. With Control Tower, the instance lives in the management account. Find its ARN under Settings in the Identity Center console. It is required when any space sets `identity_center_enabled`.

The deployment role needs `aidevops:EnableOperatorApp`, `aidevops:DisableOperatorApp` and `sso:DescribeApplication` in addition to the existing permissions. Check the first apply for access denied errors on other `sso:` actions, since AWS does not fully document what enabling Identity Center calls on the caller's behalf.

Setting `identity_center_enabled` back to false does not disconnect Identity Center from the space. Disconnect it in the AWS DevOps Agent console if needed.

## Secondary Accounts

An Agent Space can investigate resources in other accounts of the organization. List their account IDs, in quotes, under `source_accounts` in the space's YAML file.

The agent assumes a role named `DevOpsAgentRole-AgentSpace` in each secondary account. To use a different name, set `source_account_role_name` in `terragrunt.hcl`. The role is created outside this repository. It needs:

- A trust policy that allows `aidevops.amazonaws.com` to call `sts:AssumeRole`, with `aws:SourceAccount` set to this monitoring account. Set `aws:SourceArn` to the Agent Space ARN, or to `arn:aws:aidevops:ca-central-1:<monitoring-account-id>:agentspace/*` to allow every space in this account.
- The `AIDevOpsAgentAccessPolicy` AWS managed policy.
- Optionally, permission to create the Resource Explorer service-linked role in that account, as the agent role in this account has.

Removing an account from the list removes only that account's association.

## Deploy

The CI definitions are `.github/workflows/tf_plan.yml` and `.github/workflows/tf_apply.yml`.

The intended release sequence is:

1. Open a pull request with the Terragrunt changes and review the plan produced by the plan workflow. Pay particular attention to IAM permissions, role trust relationships, account ID, Region, and Agent Space settings.
2. Merge the reviewed change to `main` to trigger the apply workflow.
3. After a successful apply, verify the Agent Space, account associations, and resource discovery in AWS.

To upgrade providers within the declared constraints, update the configuration as needed and review the resulting plan through CI. The AWS provider constraint `~> 6.0` permits 6.x releases, but not 7.x.

## Outputs

- `agent_spaces`: a map keyed by team identifier with each space's `id`, `arn`, `name`, `devops_agent_role_arn`, `operator_role_arn`, `identity_center_application_arn`, `identity_center_application_id` and `source_account_ids`.
- `monitoring_account_id`

Verify the Agent Space in the AWS DevOps Agent console and confirm that the account associations and resource discovery are active.

## Security and Operations

- Keep Terraform state in the configured remote backend; state can contain sensitive infrastructure details.
- Keep IAM responsibilities separate: the agent role grants the service access to inspect resources, while the operator role controls access to the web application.
- Web app access is controlled by Identity Center assignments in the landing zone repository. Keep group membership tight, and remove direct user assignments made in the console.
- Review AWS-managed policy changes and the generated Terraform plan before applying.
- Avoid logging credentials, tokens, personal information, payment details, or other sensitive data that the agent may process.
- Check current AWS documentation for supported Regions, service requirements, IAM policies, and resource schemas because AWS DevOps Agent and its Cloud Control resources can evolve.

Inspired by the AWS Build Center article "Deploying AWS DevOps Agent using Terraform" by Haytham Mostafa