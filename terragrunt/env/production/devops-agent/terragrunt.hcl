terraform {
  source = "../../../aws//devops-agent"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  # One entry per team. To add an Agent Space, add a new entry below and open a PR.
  # The key is a short, stable team identifier (lowercase letters, numbers, hyphens).
  # Do not rename a key once applied: that destroys and recreates the Agent Space.
  agent_spaces = {
    sre = {
      name             = "CDS SRE agent space"
      description      = "AWS DevOps Agent Space for the production sre tools platform"
      application_name = "sre-tools-platform"
    }

    # example-team = {
    #   name             = "CDS Example Team agent space"
    #   description      = "AWS DevOps Agent Space for the example team"
    #   application_name = "example-application"
    #   tags             = { Team = "example-team" } # optional
    # }
  }
}
