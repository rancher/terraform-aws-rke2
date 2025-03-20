package fixtures

import (
	"encoding/json"
	"testing"

	aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// The user's environment is expected to have ZONE set with the Route53 domain zone to create the domain name in.
type FixtureData struct {
	Id                string
	Name              string
	DataDirectory     string
	Release           string
	OperatingSystem   string
	Cni               string
	InstallType       string
	IpFamily          string
	IngressController string
	Region            string
	Owner             string
	ExampleDirectory  string // This is actually the test_relay directory
	Zone              string
	AcmeServer        string
	SshAgent          *ssh.SshAgent
	SshKeyPair        *aws.Ec2Keypair
	TfOptions         *terraform.Options
	TfVars            map[string]interface{}
}

func create(t *testing.T, d *FixtureData) (string, string, error) {
	var err error
	terraformOptions := GenerateOptions(t, d)
	t.Logf("Git Root: %s", d.ExampleDirectory)
	d.SshKeyPair, err = GenerateKey(t, d)
	if err != nil {
		t.Errorf("Error creating key pair: %s", err)
		aws.DeleteEC2KeyPair(t, d.SshKeyPair)
		return "", "", err
	}
	d.SshAgent = GenerateSshAgent(t, d)
	terraformOptions.SshAgent = d.SshAgent

	testDataDir := d.DataDirectory + "/test"

	terraformOptions.Vars = map[string]interface{}{
		"rke2_version":       d.Release,
		"os":                 d.OperatingSystem,
		"zone":               d.Zone,
		"key_name":           d.SshKeyPair.Name,
		"key":                d.SshKeyPair.KeyPair.PublicKey,
		"identifier":         d.Id,
		"install_method":     d.InstallType,
		"cni":                d.Cni,
		"ip_family":          d.IpFamily,
		"ingress_controller": d.IngressController,
		"fixture":            d.Name,
	}

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

	_, err = terraform.InitAndApplyE(t, d.TfOptions)
	if err != nil {
		t.Errorf("Error creating cluster: %s", err)
		return "", "", err
	}

	output := terraform.OutputJson(t, terraformOptions, "")
	type OutputData struct {
		Kubeconfig struct {
			Sensitive bool   `json:"sensitive"`
			Type      string `json:"type"`
			Value     string `json:"value"`
		} `json:"kubeconfig"`
    Api struct {
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
  assert.NotEmpty(t, data.Api.Value)
  t.Logf("api: %s", data.Api.Value)
	return data.Kubeconfig.Value, data.Api.Value, nil
}
