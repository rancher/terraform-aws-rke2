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

// The user's environment is expected to have ZONE set with the Route53 domain zone to create the domain name in.

type FixtureData struct {
	Id 							 string
	Name 						 string
	DataDirectory 	 string
	Release 				 string
	OperatingSystem  string
	Region 					 string
	ExampleDirectory string
	Zone						 string
	AcmeServer			 string
	SshAgent				 *ssh.SshAgent
	SshKeyPair 			 *aws.Ec2Keypair
	TfOptions 			 *terraform.Options
	TfVars					 map[string]interface{}
}

// This generates the One example fixture; a single node Rke2 cluster.
// Outputs the kubeconfig or "" on failure.
func CreateOne(t *testing.T, d *FixtureData) (string) {
	var err error
	d.Name = "one"
	terraformOptions := GenerateOptions(t,d)
	t.Logf("Git Root: %s", d.ExampleDirectory)
	d.SshKeyPair = GenerateKey(t, d)
	d.SshAgent 	 = GenerateSshAgent(t, d)

	installDataDir := d.DataDirectory + "/install"
	testDataDir := d.DataDirectory + "/test"
	
	terraformOptions.Vars = map[string]interface{}{
		"rke2_version": d.Release,
		"os": d.OperatingSystem,
		"file_path": installDataDir,
		"zone": d.Zone,
		"key_name": d.SshKeyPair.Name,
		"key": d.SshKeyPair.PublicKey,
		"identifier": d.Id,
	}
	
	terraformOptions.EnvVars = map[string]string{
		"AWS_DEFAULT_REGION": d.Region,
		"TF_IN_AUTOMATION": "1",
		"TF_DATA_DIR": testDataDir,
		"TF_CLI_ARGS_plan": 	 "-state=" + testDataDir + "/tfstate",
		"TF_CLI_ARGS_apply": 	 "-state=" + testDataDir + "/tfstate",
		"TF_CLI_ARGS_destroy": "-state=" + testDataDir + "/tfstate",
		"TF_CLI_ARGS_output":  "-state=" + testDataDir + "/tfstate",
	}

	terraformOptions.SshAgent = d.SshAgent
	
	d.TfOptions  = terraformOptions
	
	terraform.InitAndApply(t, d.TfOptions)
	configFile, err := os.ReadFile(installDataDir + "/kubeconfig")
	if err != nil {
		t.Logf("%v", err)
		return ""
	}
	t.Logf("Config from File: \n %s",string(configFile))

	output := terraform.OutputJson(t, terraformOptions, "")
	type OutputData struct {
		Kubeconfig struct {
			Sensitive bool   `json:"sensitive"`
			Type      string `json:"type"`
			Value     string `json:"value"`
		} `json:"kubeconfig"`
	}
	var data OutputData
	t.Logf("Json Output: %s", output)
	err = json.Unmarshal([]byte(output), &data)
	if err != nil {
		t.Fatalf("Error unmarshalling Json: %v", err)
	}
	assert.NotEmpty(t, data.Kubeconfig.Value)
	return data.Kubeconfig.Value
}

