terraform {
  source = "../../../aws//devops-agent"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  # Each YAML file in agent-spaces/ defines one Agent Space.
  # The file name (without .yaml) is the team key. See the README for the file format.
  agent_space_dir = "${get_terragrunt_dir()}/agent-spaces"
}

inputs = {
  agent_spaces = {
    for f in fileset(local.agent_space_dir, "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${local.agent_space_dir}/${f}"))
  }
}
