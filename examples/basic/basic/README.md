# Terraform AWS RKE2 Basic

This example is the most basic use case for the module, it is verified by Terratest in the ./tests directory (basic_test.go).
You can run this test by navigating to the ./tests directory and running `go test -v -parallel=10 -timeout=30m -run=TestBasic`.

In this example we provision an RKE2 server using the "tar" install method, it is assumed that the server is not able to access the public internet.
The security group for this module prevents access except from or to the single IP of the server provisioning the server.
To accomplish this the module will download (to the runner) archived data from GitHub for the container images that RKE2 needs to provision properly.
It will then copy the data to the newly provisioned server and install RKE2 using the "tar" installation method.

This is the most basic example, and may be different than other examples found here.
We attempt to cover the most popular or relevant use cases in our examples.

Please let us know if you would like to see more!
