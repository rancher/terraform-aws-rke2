# Terraform AWS RKE2

This module deploys infrastructure and installs RKE2 on that infrastructure.
This module combines other modules that we provide to give holistic control of the lifecycle of a single RKE2 node.

## Requirements

#### Provider Setup

Only two of the providers require setup:

- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) : [Config Reference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#aws-configuration-reference)
- [GitHub Provider](https://registry.terraform.io/providers/integrations/github/latest/docs) : [Config Reference](https://registry.terraform.io/providers/integrations/github/latest/docs#argument-reference)

We recommend setting the following environment variables for quick personal use:

```shell
GITHUB_TOKEN
AWS_REGION
AWS_SECRET_ACCESS_KEY
AWS_ACCESS_KEY_ID
```

#### Curl

You will need Curl available on the server running Terraform.

#### Local Filesystem Write Access

You will need write access to the filesystem on the server running Terraform.
If downloading the files from GitHub (not setting 'skip_download'), then you will need about 2GB storage space available in the 'local_file_path' location (defaults to ./rke2).

#### Terraform Version

We specify the Terraform version < 1.6 to avoid potential license issues and version > 1.4.1 to enable custom variable validations.

## Examples

We have a few example implementations to get you started, these examples are tested in our CI before release.
When you use them, update the source and version to use the Terraform registry.

#### Local State

The specific use case for the example modules is temporary infrastructure for testing purposes.
With that in mind, it is not expected that we manage the resources as a team, therefore the state files are all stored locally.
If you would like to store the state files remotely, add a terraform backend file (`*.name.tfbackend`) to your root module.
https://developer.hashicorp.com/terraform/language/v1.5.x/settings/backends/configuration#file

## Development and Testing

#### Paradigms and Expectations

Please make sure to read [terraform.md](./terraform.md) to understand the paradigms and expectations that this module has for development.
This is a "Primary" module, as such it is not allowed to generate resources on its own,
it must call on "Core" modules which generate resources.

#### Environment

It is important to us that all collaborators have the ability to develop in similar environments, so we use tools which enable this as much as possible.
These tools are not necessary, but they can make it much simpler to collaborate.

* I use [nix](https://nixos.org/) that I have installed using [their recommended script](https://nixos.org/download.html#nix-install-macos)
* I use [direnv](https://direnv.net/) that I have installed using brew.
* I simply use `direnv allow` to enter the environment
* I navigate to the `tests` directory and run `go test -v -timeout=40m -parallel=10`

  * It is important to note that the test files do not stand alone, they expect to run as a package.
  * This means that specifying the file to test (as follows) will fail: `go test -v -timeout 40m -parallel 10 basic_test.go`
* To run an individual test I navigate to the `tests` directory and run `go test -v -timeout 40m -parallel 10 -run <test function name>`

  * eg. `go test -v -timeout 40m -parallel 10 -run TestBasic`
* I store my credentials in a local files and generate a symlink to them

  * eg. `~/.config/github/default/rc`
  * this will be automatically sourced when you enter the nix environment (and unloaded when you leave)
  * see the `.envrc` and `.rcs` file for the implementation

#### Automated Tests

Our continuous integration tests using the GitHub [ubuntu-latest runner](https://github.com/actions/runner-images/blob/main/images/linux/Ubuntu2204-Readme.md) which has many different things installed and does not rely on Nix.

It also has special integrations with AWS to allow secure authentication, see https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services for more information.
