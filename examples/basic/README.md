# Terraform AWS RKE2 Basic

This example is the most basic use case for the module, it is verified by Terratest in the ./tests directory (test_basic.go).
You can run this test by navigating to the ./tests directory and running `go test -v -parallel=10 -timeout=30m -run TestBasic`.

Terraform is a tool which enables infrastructure as code (IAC).
Terratest is a go sdk which is helpful to use when testing Terraform configurations.

We make some decisions in this example to enable clean testing that you can leave out in your production root module.

1. We generate ssh keys in terratest for each run of this module

   1. you will not want this if you intend to manage your infra over a long period of time
   2. this means you can leave out the variables.tf and hard code the ssh_key_name and ssh_key_content
   3. I suggest hard coding variables into root modules and securing them appropriately
      1. Terraform's paradigms work well when combined with GitOps, where an update to a file ends in an update to infrastructure
      2. Treating your IAC as you would infrastructure makes sense in this context, since one is the intended state of the other
      3. You should therefore secure your IAC as you would your infrastructure, with access controls and audit-ability
         1. don't forget that your state file is a part of your IAC and needs to be secured as well
      4. Hard coding the variables in root modules (aka "implementation modules") allows the engineers who have access to the code and infrastructure a clear and concise look when something needs to be troubleshooted (another goal of IAC).
      5. This practice can save minutes or even hours of downtime during critical moments.
2. We allow the test to determine what version of rke2 to install

   1. you should pin the version of rke2 that you want to install in your root module
   2. even when supplying your own tarballs to the installer it is important to specify the version
   3. this prevents Terraform from overriding your config and accidentally wiping out your server
   4. this means you can leave out the variables.tf and hard code the rke2_version in your root module
   5. I suggest hard coding variables into root modules and securing them appropriately

      1. Terraform's paradigms work well when combined with GitOps, where an update to a file ends in an update to infrastructure
      2. Treating your IAC as you would infrastructure makes sense in this context, since one is the intended state of the other
      3. You should therefore secure your IAC as you would your infrastructure, with access controls and audit-ability

         1. don't forget that your state file is a part of your IAC and needs to be secured as well
      4. Hard coding the variables in root modules (aka "implementation modules") allows the engineers who have access to the code and infrastructure a clear and concise look when something needs to be troubleshooted (another goal of IAC).
      5. This practice can save minutes or even hours of downtime during critical moments

## WARNING: private ssh keys

This module does not manage any private ssh keys and assumes you have an ssh-agent installed, running, and loaded with a key to connect to your server. You should not provide your private key to anyone under any circumstance. Best practice is to have a different ssh key for each client you use to connect to servers, with the private key living on the client and never being shared. The key you provide to this module should be the public key which is saved in state, imported to EC2, and added to the "authorized_keys" file on the server.
