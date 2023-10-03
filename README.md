# Terraform AWS RKE2

WARNING! this module is experimental

This module deploys infrastructure and installs RKE2 on that infrastructure.
This module combines other modules that we provide to give holistic control of the lifecycle of an RKE2 node.

## Local File Path

The `local_file_path` variable informs the module whether or not to download files from GitHub.

- If the variable indicates a path on the local file system, then the module will not attempt to download anything.
- If the value of the variable is "", then the module assumes you need it to download the files, and initiates the GitHub provider to do so.
  - this means that you only need a GitHub token if you need to download the files

This module does not attempt to alter the contents of files supplied in the `local_file_path` variable.

## Curl and Local Filesystem Write Access

If you decide to let the module download files from GitHub, you need to have write permissions on the local filesystem,
 and `curl` installed on the machine running Terraform.
You will also need to have a GitHub token, see [GitHub Access](#github-access) below.

## Release

This is the version of rke2 to install, even when supplying the files it is necessary to specify the exact version of rke2 you are installing.

- If the release version changes, this module will attempt to run the installation again. (this may not work)

## GitHub Access

The GitHub provider [provides multiple ways to authenticate](https://registry.terraform.io/providers/integrations/github/latest/docs#authentication) with GitHub.
For simplicity we use the `GITHUB_TOKEN` environment variable when testing.
The GitHub provider is not used when `local_file_path` is specified!
This means that you don't need to provide any information to that provider and it will not attempt to make connections.

## Examples

### Local State

The specific use case for the example modules is temporary infrastructure for testing purposes.
With that in mind, it is not expected that we manage the resources as a team, therefore the state files are all stored locally.
If you would like to store the state files remotely, add a terraform backend file (`*.name.tfbackend`) to your implementation module.
https://www.terraform.io/language/settings/backends/configuration#file

## Development and Testing

### Paradigms and Expectations

Please make sure to read [terraform.md](./terraform.md) to understand the paradigms and expectations that this module has for development.
This is a "Primary" module, as such it is not allowed to generate resources on its own,
it must call on "Core" modules which generate resources.

### Environment

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
* I use `override.tf` files to change the values of `examples` to personalized data so that I can run them.
  * some examples use variables so that I can dynamically add values in tests
* I store my GitHub credentials in a local file and generate a symlink to them named `~/.config/github/default/rc`
  * this will be automatically sourced when you enter the nix environment (and unloaded when you leave)

Our continuous integration tests in the GitHub [ubuntu-latest runner](https://github.com/actions/runner-images/blob/main/images/linux/Ubuntu2204-Readme.md), which has many different things installed and does not rely on Nix.
It also uses a custom role and user which has been set up for it.
