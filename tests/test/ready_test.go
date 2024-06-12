package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	fit "github.com/rancher/terraform-aws-rke2/tests/fixtures"

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
		"sles-15-canal-latest-one-rpm-ipv4-nginx",
		"sles-15-calico-stable-one-rpm-ipv4-nginx",
		"sle-micro-55-canal-old-one-rpm-ipv4-nginx",
		"sle-micro-55-canal-old-one-tar-ipv4-nginx",
		"sle-micro-55-cilium-latest-one-rpm-ipv4-nginx",
		"rhel-8-cis-cilium-latest-one-rpm-ipv4-nginx",
		"ubuntu-22-canal-stable-one-tar-ipv4-nginx",
		"sles-15-canal-latest-ha-rpm-ipv4-nginx",
		"sle-micro-55-canal-latest-splitrole-rpm-ipv4-nginx",
	}

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
			defer terraform.Destroy(t, d.TfOptions)
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
