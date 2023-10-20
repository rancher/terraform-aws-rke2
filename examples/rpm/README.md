# Terraform AWS RKE2 RPM

This example is the most basic use case for the module, it is verified by Terratest in the ./tests directory (rpm_test.go).
You can run this test by navigating to the ./tests directory and running `go test -v -parallel=10 -timeout=30m -run=TestRpm`.

In this example we provision an RKE2 server using the "rpm" install method, it is assumed that the server is able to access the public internet for downloading the RPMs.

We attempt to cover the most popular or relevant use cases in our examples.
Please let us know (create an issue) if you would like to see more!
