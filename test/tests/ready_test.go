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
		// "ubuntu-22-canal-stable-one-tar-ipv4-nginx",
		// "sles-15-canal-stable-one-rpm-ipv4-nginx",
		// "rhel-9-canal-stable-one-rpm-ipv4-nginx",
		// "rhel-8-canal-stable-one-rpm-ipv4-nginx",
		// "sle-micro-55-canal-stable-one-rpm-ipv4-nginx",
		// "rhel-8-cis-canal-stable-one-rpm-ipv4-nginx",
		// "ubuntu-20-canal-stable-one-tar-ipv4-nginx", // not working
		// "rocky-8-canal-stable-one-rpm-ipv4-nginx", // not working
		// "liberty-7-canal-stable-one-rpm-ipv4-nginx", // not working

		// cni tests
		// "sle-micro-55-cilium-stable-one-rpm-ipv4-nginx",
		// "sle-micro-55-calico-stable-one-rpm-ipv4-nginx",

		// version tests
		// "sle-micro-55-canal-latest-one-rpm-ipv4-nginx",
		// "sle-micro-55-canal-old-one-rpm-ipv4-nginx",
		// multinode fixtures
		"sle-micro-55-canal-stable-ha-rpm-ipv4-nginx", // (ha not ready)
		// "sles-15-canal-stable-ha-rpm-ipv4-nginx", (ha not ready)
		// "ubuntu-22-canal-stable-ha-tar-ipv4-nginx", (ha not ready)
		// "sle-micro-55-canal-stable-splitrole-rpm-ipv4-nginx", (splitrole not ready)
		// "sles-15-canal-stable-splitrole-rpm-ipv4-nginx", (splitrole not ready)
		// "ubuntu-22-canal-stable-splitrole-tar-ipv4-nginx", (splitrole not ready)
		// "sle-micro-55-canal-stable-db-rpm-ipv4-nginx", (db test not yet implemented)
		// "sles-15-canal-stable-db-rpm-ipv4-nginx", (db test not yet implemented)
		// "ubuntu-22-canal-stable-db-tar-ipv4-nginx", (db test not yet implemented)
		// install method tests
		// "sle-micro-55-canal-stable-one-tar-ipv4-nginx",
		// "sles-15-canal-stable-one-tar-ipv4-nginx",
		// ipv6 tests
		// "ubuntu-22-canal-stable-one-tar-ipv6-nginx",
		// "sles-15-canal-stable-one-rpm-ipv6-nginx",
		// "sle-micro-55-canal-stable-one-rpm-ipv6-nginx",
		// ingress tests (not yet implemented)
		// "ubuntu-22-canal-stable-one-tar-ipv4-traefik",
		// "sles-15-canal-stable-one-rpm-ipv4-traefik",
		// "sle-micro-55-canal-stable-one-rpm-ipv4-traefik",
	}
	// this combo not currently possible due to kernel parameters set on the image along with AWS networking expectations
	// "rhel-8-cis-cilium-latest-one-rpm-ipv6-nginx",
	// rpm install method is not supported for ubuntu

	combinations := make(map[string]map[string]string)
	for i := range selection {
		combinations[selection[i]] = cc[selection[i]]
	}

	t.Logf("Running these tests: %v", combinations)

	for k, v := range combinations {
		t.Run(k, func(t *testing.T) {
			t.Parallel()
			t.Logf("Running test for %s", k)
			//kubeconfigPath, _, err := fit.CreateFixture(t, v)
			kubeconfigPath, d, err := fit.CreateFixture(t, v)
			defer fit.Teardown(t, &d)
			require.NoError(t, err)
			assert.NotEmpty(t, kubeconfigPath)
			checkReady(t, kubeconfigPath)
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
