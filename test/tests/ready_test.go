package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
	fit "github.com/rancher/terraform-aws-rke2/test/fixtures"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func GetCombinations(t *testing.T) {
	cc, err := fit.GetCombinations(t)
	require.NoError(t, err)
	for k, v := range cc {
		t.Logf("%s", k)
		t.Logf("%v", v)
	}
}

func TestMatrix(t *testing.T) {
	t.Logf("%s", os.Getenv("IDENTIFIER"))
	if os.Getenv("GITHUB_TOKEN") == "" {
		t.Fatal("GITHUB_TOKEN is not set")
	}
	cc, err := fit.GetCombinations(t)
	require.NoError(t, err)

	// only use a few combos for now, we can expand later
	selection := []string{
		// necessary tests
		//// os
		"sle-micro-60-canal-stable-one-rpm-ipv4-nginx",
		"sles-15-canal-stable-one-rpm-ipv4-nginx",
		"cis-rhel-8-canal-stable-one-rpm-ipv4-nginx",
		"ubuntu-24-canal-stable-one-tar-ipv4-nginx", // also counts as air gapped test
		"rhel-9-canal-stable-one-rpm-ipv4-nginx",
		//// cni
		"sle-micro-60-cilium-stable-one-rpm-ipv4-nginx",
		"sle-micro-60-calico-stable-one-rpm-ipv4-nginx",
		//// version
		"sle-micro-60-canal-latest-one-rpm-ipv4-nginx",
		"sle-micro-60-canal-old-one-rpm-ipv4-nginx",
		//// ipv6 tests
		"sle-micro-60-canal-stable-one-rpm-ipv6-nginx",
		//// ha
		"sle-micro-60-canal-stable-ha-rpm-ipv4-nginx",
		//// splitrole
		"sle-micro-60-canal-stable-splitrole-rpm-ipv4-nginx",
		//// prod
		"sle-micro-60-canal-stable-prod-rpm-ipv4-nginx",
		//// confirmed use cases
		"ubuntu-22-canal-stable-one-tar-ipv4-nginx", // https://github.com/rancher/terraform-aws-rke2/issues/153

		// extended tests
		// os
		// "sle-micro-55-canal-stable-one-rpm-ipv4-nginx",
		// "rocky-9-canal-stable-one-tar-ipv4-nginx",
		// "liberty-8-canal-stable-one-rpm-ipv4-nginx",
		//// ha
		// "sles-15-canal-stable-ha-rpm-ipv4-nginx",
		// "ubuntu-24-canal-stable-ha-tar-ipv4-nginx",
		//// splitrole
		// "sles-15-canal-stable-splitrole-rpm-ipv4-nginx",
		// "ubuntu-24-canal-stable-splitrole-tar-ipv4-nginx",
		//// prod
		// "sles-15-canal-stable-prod-rpm-ipv4-nginx",
		// "ubuntu-24-canal-stable-prod-tar-ipv4-nginx",
		//// airgapped
		// "sle-micro-60-canal-stable-one-tar-ipv4-nginx",
		// "sles-15-canal-stable-one-tar-ipv4-nginx",
		//// ipv6
		// "ubuntu-24-canal-stable-one-tar-ipv6-nginx",
		// "sles-15-canal-stable-one-rpm-ipv6-nginx",
		// "sle-micro-60-canal-stable-ha-rpm-ipv6-nginx",
		// "sle-micro-60-canal-stable-splitrole-rpm-ipv6-nginx",
		// "sle-micro-60-canal-stable-prod-rpm-ipv6-nginx",

		// ingress tests (not yet implemented)
		// "ubuntu-24-canal-stable-one-tar-ipv4-traefik",
		// "sles-15-canal-stable-one-rpm-ipv4-traefik",
		// "sle-micro-60-canal-stable-one-rpm-ipv4-traefik",
	}
	//Unsupported Combos:
	// "cis-...-ipv6-...",
	//// kernel parameters set on the CIS STIG image disables dhcpv6 which AWS requires for dedicated ipv6 access
	// "ubuntu-...-rpm-...",
	//// rpm install method is not supported for ubuntu

	combinations := make(map[string]map[string]string)
	for i := range selection {
		combinations[selection[i]] = cc[selection[i]]
	}

	t.Logf("Running these tests: %v", combinations)

	for k, v := range combinations {
		t.Run(k, func(t *testing.T) {
			t.Parallel()
			t.Logf("Running test for %s", k)
			kubeconfigPath, d, err := fit.CreateFixture(t, v)
			if err != nil {
				t.Logf("Error creating cluster: %s", err)
				t.Fail()
				fit.Teardown(t, &d)
			}
			t.Logf("Fixture %s created, checking...", k)
			assert.NotEmpty(t, kubeconfigPath)
			checkReady(t, kubeconfigPath)
			t.Log("Test complete, tearing down...")
			fit.Teardown(t, &d)
		})
	}
}

func checkReady(t *testing.T, kubeconfigPath string) {
	script, err2 := os.ReadFile("./scripts/readyNodes.sh")
	if err2 != nil {
		require.NoError(t, err2)
	}
	readyScript := shell.Command{
		Command: "bash",
		Args:    []string{"-c", string(script)},
		Env: map[string]string{
			"KUBECONFIG": kubeconfigPath,
		},
	}
	out := shell.RunCommandAndGetOutput(t, readyScript) // if the script fails, it will fail the test
	t.Logf("Ready script output: %s", out)
}
