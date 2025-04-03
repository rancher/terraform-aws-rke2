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
		"sle-micro-61-canal-stable-one-rpm-ipv4-nginx",
		"sles-15-canal-stable-one-rpm-ipv4-nginx",
		"cis-rhel-8-canal-stable-one-rpm-ipv4-nginx",
		"ubuntu-24-canal-stable-one-tar-ipv4-nginx", // also counts as air gapped test
		"rhel-9-canal-stable-one-rpm-ipv4-nginx",
		//// cni
		"sle-micro-61-cilium-stable-one-rpm-ipv4-nginx",
		"sle-micro-61-calico-stable-one-rpm-ipv4-nginx",
		//// version
		"sle-micro-61-canal-latest-one-rpm-ipv4-nginx",
		"sle-micro-61-canal-old-one-rpm-ipv4-nginx",
		//// ipv6 tests
		"sle-micro-61-canal-stable-one-rpm-ipv6-nginx",
		//// dualstack tests
		"sle-micro-61-canal-stable-one-rpm-dualstack-nginx",
		//// ha
		"sle-micro-61-canal-stable-ha-rpm-ipv4-nginx",
		//// splitrole
		"sle-micro-61-canal-stable-splitrole-rpm-ipv4-nginx",
		//// prod
		"sle-micro-61-canal-stable-prod-rpm-ipv4-nginx",
		//// confirmed use cases
		"ubuntu-22-canal-stable-one-tar-ipv4-nginx", // https://github.com/rancher/terraform-aws-rke2/issues/153

		// extended tests
		// os
		// "sle-micro-55-canal-stable-one-rpm-ipv4-nginx",
		// "rocky-9-canal-stable-one-rpm-ipv4-nginx",
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
		// "sle-micro-61-canal-stable-one-tar-ipv4-nginx",
		// "sles-15-canal-stable-one-tar-ipv4-nginx",
		//// ipv6
		// "ubuntu-24-canal-stable-one-tar-ipv6-nginx",
		// "sles-15-canal-stable-one-rpm-ipv6-nginx",
		// "sle-micro-61-canal-stable-ha-rpm-ipv6-nginx",
		// "sle-micro-61-canal-stable-splitrole-rpm-ipv6-nginx",
		// "sle-micro-61-canal-stable-prod-rpm-ipv6-nginx",

		// ingress tests (not yet implemented)
		// "ubuntu-24-canal-stable-one-tar-ipv4-traefik",
		// "sles-15-canal-stable-one-rpm-ipv4-traefik",
		// "sle-micro-61-canal-stable-one-rpm-ipv4-traefik",
	}
	//Unsupported Combos:
	// "cis-...-ipv6-...",
	//// kernel parameters set on the CIS STIG image disables dhcpv6 which AWS requires for dedicated ipv6 access
	// "ubuntu-...-rpm-...",
	//// rpm install method is not supported for Ubuntu
	// "rocky-...-tar-..."
	//// tar install method isn't supported for Rocky (doesn't come with overlayfs enabled)
  combo := os.Getenv("COMBO")
  if combo != "" {
    t.Logf("Running single combo: %s", combo)
    selection = []string{combo}
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
			kubeconfigPath, api, d, err := fit.CreateFixture(t, v)
			if err != nil {
				t.Logf("Error creating cluster: %s", err)
				t.Fail()
				fit.Teardown(t, &d)
			}
			t.Logf("Fixture %s created, checking...", k)
			assert.NotEmpty(t, kubeconfigPath)
      assert.NotEmpty(t, api)
      t.Logf("API: %s", api)
      t.Logf("Kubeconfig: %s", kubeconfigPath)
			checkReady(t, kubeconfigPath, api, d)
			if t.Failed() {
				t.Log("Test failed...")
			} else {
				t.Log("Test passed...")
			}
			t.Log("Test complete, tearing down...")
			fit.Teardown(t, &d)
		})
	}
}

func checkReady(t *testing.T, kubeconfigPath string, api string, d fit.FixtureData) {
	script, err2 := os.ReadFile("./scripts/readyNodes.sh")
	if err2 != nil {
		require.NoError(t, err2)
	}
	readyScript := shell.Command{
		Command: "bash",
		Args:    []string{"-c", string(script)},
		Env: map[string]string{
			"KUBECONFIG": kubeconfigPath,
      "API": api,
      "WAIT": os.Getenv("WAIT"),
		},
	}
	out, err := shell.RunCommandAndGetOutputE(t, readyScript)
  if err != nil {
    t.Logf("Error running script: %s", err)
    t.Fail()
  }
	t.Logf("Ready script output: %s", out)
}
