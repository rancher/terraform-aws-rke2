package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestRpm(t *testing.T) {
	t.Parallel()
	uniqueID := random.UniqueId()
	directory := "rpm"
	region := "us-east-1" // this must match the region set in the example
	owner := "terraform-ci@suse.com"
	release := getLatestRelease(t, "rancher", "rke2")
	terraformVars := map[string]interface{}{
		"rke2_version": release,
	}
	terraformOptions, keyPair := setup(t, directory, region, owner, uniqueID, terraformVars)

	sshAgent := ssh.SshAgentWithKeyPair(t, keyPair.KeyPair)
	defer sshAgent.Stop()
	terraformOptions.SshAgent = sshAgent

	defer teardown(t, directory, keyPair)
	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

}
