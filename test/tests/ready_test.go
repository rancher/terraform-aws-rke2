package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
	// "github.com/gruntwork-io/terratest/modules/terraform"
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
	t.Logf("%s", os.Getenv("ZONE"))
	if os.Getenv("GITHUB_TOKEN") == "" {
		t.Fatal("GITHUB_TOKEN is not set")
	}
	cc, err := fit.GetCombinations(t)
	require.NoError(t, err)

	// only use a few combos for now, we can expand later
	selection := []string{
		// os tests
		// "sle-micro-55-canal-stable-one-rpm-ipv4-nginx",
		// // "sle-micro-60-canal-stable-one-rpm-ipv4-nginx",
		// "sles-15-canal-stable-one-rpm-ipv4-nginx",
		// "rhel-9-canal-stable-one-rpm-ipv4-nginx",
		// // "rocky-9-canal-stable-one-tar-ipv4-nginx",
		// "rhel-8-cis-canal-stable-one-rpm-ipv4-nginx",
		// // "liberty-8-canal-stable-one-rpm-ipv4-nginx",
		// // "ubuntu-24-canal-stable-one-tar-ipv4-nginx",
		// "ubuntu-22-canal-stable-one-tar-ipv4-nginx",

		// cni tests
		// "sle-micro-55-cilium-stable-one-rpm-ipv4-nginx",
		// "sle-micro-55-calico-stable-one-rpm-ipv4-nginx",

		// version tests
		// "sle-micro-55-canal-latest-one-rpm-ipv4-nginx",
		// "sle-micro-55-canal-old-one-rpm-ipv4-nginx",

		// multinode fixtures
		//// basic HA
		"sle-micro-55-canal-stable-ha-rpm-ipv4-nginx",
		// "sles-15-canal-stable-ha-rpm-ipv4-nginx",
		// "ubuntu-22-canal-stable-ha-tar-ipv4-nginx",
		// "sle-micro-55-canal-stable-ha-rpm-ipv6-nginx",

		//// dedicated control plane
		// "sle-micro-55-canal-stable-splitrole-rpm-ipv4-nginx",
		// "sles-canal-stable-splitrole-rpm-ipv4-nginx", (splitrole not ready)
		// "ubuntu-canal-stable-splitrole-tar-ipv4-nginx", (splitrole not ready)

		//// dedicated database (etcd)
		// "sle-micro-canal-stable-db-rpm-ipv4-nginx", (db test not yet implemented)
		// "sles-canal-stable-db-rpm-ipv4-nginx", (db test not yet implemented)
		// "ubuntu-canal-stable-db-tar-ipv4-nginx", (db test not yet implemented)

		// airgapped install tests
		// "sle-micro-canal-stable-one-tar-ipv4-nginx",
		// "sles-canal-stable-one-tar-ipv4-nginx",
		// "ubuntu-canal-stable-one-tar-ipv4-nginx",

		// ipv6 tests
		// "ubuntu-canal-stable-one-tar-ipv6-nginx",
		// "sles-canal-stable-one-rpm-ipv6-nginx",
		// "sle-micro-canal-stable-one-rpm-ipv6-nginx",

		// ingress tests (not yet implemented)
		// "ubuntu-canal-stable-one-tar-ipv4-traefik",
		// "sles-canal-stable-one-rpm-ipv4-traefik",
		// "sle-micro-canal-stable-one-rpm-ipv4-traefik",
	}
	//Unsupported Combos:
	// "rhel-8-cis-...-ipv6-...",
	//// kernel parameters set on the STIG image disables dhcpv6 which AWS requires for dedicated ipv6 access
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
