package fixtures

import (
	"encoding/json"
	"os"
	"testing"

	aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// FixtureData holds the state and configuration for a given test fixture.
// The user's environment is expected to have ZONE set with the Route53 domain zone to create the domain name in.
type FixtureData struct {
	ID               string
	Name             string
	DataDirectory    string
	Release          string
	OperatingSystem  string
	Cni              string
	InstallType      string
	IPFamily         string
	Region           string
	Owner            string
	ExampleDirectory string // This is actually the test_relay directory
	Zone             string
	AcmeServer       string
	SSHAgent         *ssh.SSHAgent
	SSHKeyPair       *aws.Ec2Keypair
	TfOptions        *terraform.Options
	TfVars           map[string]any
}

func create(t *testing.T, d *FixtureData) (string, string, error) {
	if os.Getenv("DRY_RUN") == "true" {
		t.Logf("[DRY RUN] Skipping create lifecycle for fixture %s", d.Name)
		return "dry_run_kubeconfig", "dry_run_api", nil
	}

	var err error
	terraformOptions := GenerateOptions(t, d)
	if d.Name == "" {
		t.Fatalf("Fixture data missing fixture name.")
	}
	d.SSHKeyPair, err = GenerateKey(t, d)
	if err != nil {
		t.Errorf("Error creating key pair: %s", err)
		aws.DeleteEC2KeyPairContext(t, t.Context(), d.SSHKeyPair)
		return "", "", err
	}
	d.SSHAgent = GenerateSSHAgent(t, d)
	terraformOptions.SshAgent = d.SSHAgent

	testDataDir := d.DataDirectory + "/test"

	vars := map[string]any{
		"key_name":   d.SSHKeyPair.Name,
		"key":        d.SSHKeyPair.PublicKey,
		"identifier": d.ID,
	}

	repoZip := os.Getenv("TEST_REPO_ZIP")
	if repoZip != "" {
		vars["repo_archive_path"] = repoZip
	} else {
		vars["rke2_version"] = d.Release
		vars["os"] = d.OperatingSystem
		vars["zone"] = d.Zone
		vars["install_method"] = d.InstallType
		vars["cni"] = d.Cni
		vars["ip_family"] = d.IPFamily
	}

	terraformOptions.Vars = vars

	terraformOptions.EnvVars = map[string]string{
		"AWS_DEFAULT_REGION":  d.Region,
		"TF_IN_AUTOMATION":    "1",
		"TF_DATA_DIR":         testDataDir,
		"TF_CLI_ARGS_plan":    "-state=" + testDataDir + "/tfstate",
		"TF_CLI_ARGS_apply":   "-state=" + testDataDir + "/tfstate",
		"TF_CLI_ARGS_destroy": "-state=" + testDataDir + "/tfstate",
		"TF_CLI_ARGS_output":  "-state=" + testDataDir + "/tfstate",
	}

	terraformOptions.Upgrade = true

	d.TfOptions = terraformOptions

	_, err = terraform.InitAndApplyContextE(t, t.Context(), d.TfOptions)
	if err != nil {
		t.Errorf("Error creating cluster: %s", err)
		return "", "", err
	}

	if repoZip != "" {
		return "", "", nil
	}

	output := terraform.OutputJSONContext(t, t.Context(), terraformOptions, "")
	type OutputData struct {
		Kubeconfig struct {
			Sensitive bool   `json:"sensitive"`
			Type      string `json:"type"`
			Value     string `json:"value"`
		} `json:"kubeconfig"`
		API struct {
			Sensitive bool   `json:"sensitive"`
			Type      string `json:"type"`
			Value     string `json:"value"`
		} `json:"api"`
	}
	var data OutputData
	err = json.Unmarshal([]byte(output), &data)
	if err != nil {
		t.Errorf("Error unmarshalling Json: %v", err)
	}
	assert.NotEmpty(t, data.Kubeconfig.Value)
	t.Logf("kubeconfig: %s", data.Kubeconfig.Value)
	assert.NotEmpty(t, data.API.Value)
	t.Logf("api: %s", data.API.Value)
	return data.Kubeconfig.Value, data.API.Value, nil
}
