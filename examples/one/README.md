# Example One Node Cluster

This is an example of generating a single node cluster.

## Requirements

There are a few external tools necessary for this example to work:
- Terraform (v1.5.7)
- shell (bash)
- chmod
- cat
- install
- scp
- sed (mac or ubuntu)

I use [Nix](https://nixos.org/) to declare and manage my dependencies, see the flake.nix and flake.lock files in the root of this repo.
This is the flake I use for development, so it contains more dependencies than are necessary for this example.

I validate on Mac locally and Ubuntu in CI.

## So Many Variables?

This example is used as a fixture for many tests, so there are some fields which are unnecessarily variablized.

In practice it is best to reduce the number of variables specified in a root module.
I generally suggest securing the repo properly and hard coding everything but I understand this may not scale well, or work for all use cases.
Please keep in mind that secrets passed to variables are stored in plain text in the Terraform state file and secure your state appropriately.
This example assumes local file state, but can be easily modified to use remote state with a backend.tf.
When working with CI, I generally use automation to encode and decode my state file locally in the repo, using an AGE encryption key.

## So Many Fields!

This example explicitly lays out all the fields that may be used to configure a cluster, many of these fields are optional and the module will default to a sane value.
To see a slimmed down version, see the "simple" example, which specifies only the required fields.
