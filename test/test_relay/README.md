# Test Relay

Many ISP don't support IPv6 native, so to test IPv6 only deployments we need a relay.
Normalizing the process, we can use the test relay to communicate what we expect a terraform runner to look like.
Since we control what runs the terraform code we can better communicate dependencies and best practices for the terraform runner.
We also bypass a lot of complexity/uncertainty about the terraform runner.
We also have the opportunity to test/validate interesting configurations,
 like having the tf runner in the same air-gapped network as what it is deploying.

## Usage in Testing

Tests which implement an ipv6 only fixture should deploy this before deploying the fixture.
The ipv6 fixture should use the ipv6 relay's ipv6 address as the runner ip.
This will allow ingress to the fixture using the ipv6 address.

When the runner attempts to connect to the server to provision rke2 it should go through the relay to get there.
We can achieve this with Tailscale, but that makes the assumption that the runner has tailscale installed and has allowed the dynamic relay to act as an exit node.
We need something that can be implemented on both a local workstation and a GH runner.
It seems like GH Runners may not have ipv6 enabled as well so this needs to be a solution that works on both.

I think this means that the relay needs to become the Terraform runner.
This could be a good paradigm for ensuring that the Terraform examples run in many different user environments.

## Enabling the relay

For the relay to become the terraform runner we need to copy the example from the local file system to the runner.
We should be able to use scp to do this, but there is probably a way to do this using golang packages.

We need to install terraform, probably from binary.
curl, scp, and jq should also be installed on the runner.

Should we install nix?
I think the nix flake is great for a devlopment environment, but this is an opportunity to show/test what a production runner might look like.

## Tailscale

Maybe installing tailscale for testing is a good idea.
Nix has a tailscale package, but we would need to install tailscale on the relay
Actually, no, because the tester would need a tailscale account and they would need to be able to allow the relay to act as an exit node.
This pulls in the overhead of creating an account, authenticating, and allowing the relay to act as an exit node
 on top of installing and configuring the relay.

## Custom Runner

1. The test needs to implement the runner tf, which is a dualstack server mod example
   - we can add resources to retrieve the repo in the runner tf
   - we can add resources to install the necessary tools to run the tests on the new runner
2. The test then runs a test on the runner?
The test then needs to run the terraform commands on the remote runner...

What if the runner tf includes terraform commands to run on the remote runner?
- We can pass the contents of the fixture to the runner tf
- The runner tf can pass the output from the fixture back to the test
- The output from the fixture will be included in the runner's output, which enables troubleshooting

Using Terraform to run Terraform is a problem, 
should we use the external provider or a community provider like [tfcli](https://github.com/weakpixel/terraform-provider-tfcli)

We will need to run terraform init, terraform plan, terraform apply, terraform destroy, and terraform output -json.
We will need to return the terraform json output.

## Terraform Managed By External Provider

I like using the external provider for this because it is officially supported by Hashicorp and this kind of a back door can be dangerous.
We only need the external provider when we need to ingest the output of a command and use it.
This means we really only need the external provider for the call to terraform output.
Every other command can be a terraform_data resource.
Terraform init is a one way script, we don't need to do anything to clean up on destroy.
Terraform plan is the same way
Terraform apply and destroy need to be linked though.
Terraform apply should run on create and terraform destroy on destroy.
- we can use a destroy time provisioner for this
What do we do if the terraform apply command fails?
- if the terraform apply command called by the terraform_data fails, the runner module will fail
- when the runner module fails, terratest will attempt to clean up by running destroy on the runner module
- there is a quasi state where the terraform_data failed and is therefore tainted, but because no resource object was successfully created, so destroy is not run against it
- I think we can resolve this by ignoring errors on the apply resource, then having a separate destroy resource that only has a destroy time provisioner.
- on create, the apply resource will run terraform apply and the destroy resource will noop
- on destroy the apply resource will noop, and the destroy resource will run terraform destroy
- we can have the apply resource depend on the destroy resource, so that if the apply resource fails, the destroy resource will still have been created
- since the destroy resource is already created, when the module fails and terratest attempts to clean up, the destroy resource will run terraform destroy

## Secrets

How do we get secrets to the remote server?
- we could use AGE to encrypt the secrets and then decrypt them on the remote server
  - we would need the remote server to have its own private key to decrypt the secrets
  - we would need to know what secrets are necessary, then generate an rc file locally for them
  - then we encrypt the rc file with the server's public AGE key
  - then we upload the encrypted rc file to the remote server
  - then we decrypt the rc file on the remote server with its private AGE key
  - then we source the rc file on the remote server
  - then we run the terraform commands on the remote server
Moving the secrets needs to be done as part of the runners terraform apply
- we need to be careful not to get the secrets in the runner's tf state
- if terraform never reads the contents of the rc file until it is encrypted then we can avoid the problem
- before we generate the server, we need an age key on the test runner
- so first the server is created, then an age keypair is generated on the runner server
- we need the public key to encrypt the rc file, so we will need to use an external provider resource to generate things
- 
