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
	ExampleDirectory  string
	Zone              string
	AcmeServer        string
	SshAgent          *ssh.SshAgent
	SshKeyPair        *aws.Ec2Keypair
	TfOptions         *terraform.Options
	TfVars            map[string]interface{}
}

// This generates the One example fixture; a single node Rke2 cluster.
// Outputs the kubeconfig or "" on failure.
func create(t *testing.T, d *FixtureData) string {
	var err error
	terraformOptions := GenerateOptions(t, d)
	t.Logf("Git Root: %s", d.ExampleDirectory)
	d.SshKeyPair, err = GenerateKey(t, d)
	if err != nil {
		t.Fatalf("Error creating key pair: %s", err)
		aws.DeleteEC2KeyPair(t, d.SshKeyPair)
		return ""
	}
	d.SshAgent = GenerateSshAgent(t, d)

	installDataDir := d.DataDirectory + "/install"
	testDataDir := d.DataDirectory + "/test"

	terraformOptions.Vars = map[string]interface{}{
		"rke2_version":       d.Release,
		"os":                 d.OperatingSystem,
		"file_path":          installDataDir,
		"zone":               d.Zone,
		"key_name":           d.SshKeyPair.Name,
		"key":                d.SshKeyPair.PublicKey,
		"identifier":         d.Id,
		"install_method":     d.InstallType,
		"cni":                d.Cni,
		"ip_family":          d.IpFamily,
		"ingress_controller": d.IngressController,
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

	terraformOptions.SshAgent = d.SshAgent
	terraformOptions.Upgrade = true

	d.TfOptions = terraformOptions

	_, err = terraform.InitAndApplyE(t, d.TfOptions)
	if err != nil {
		terraform.Destroy(t, d.TfOptions)
		t.Fatalf("Error creating cluster: %s", err)
		return ""
	}

	output := terraform.OutputJson(t, terraformOptions, "")
	type OutputData struct {
		Kubeconfig struct {
			Sensitive bool   `json:"sensitive"`
			Type      string `json:"type"`
			Value     string `json:"value"`
		} `json:"kubeconfig"`
	}
	var data OutputData
	err = json.Unmarshal([]byte(output), &data)
	if err != nil {
		t.Fatalf("Error unmarshalling Json: %v", err)
	}
	assert.NotEmpty(t, data.Kubeconfig.Value)
	t.Logf("kubeconfig: %s", data.Kubeconfig.Value)
	return data.Kubeconfig.Value
}
