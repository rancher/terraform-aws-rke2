package test

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	a "github.com/aws/aws-sdk-go/aws"
	aws "github.com/gruntwork-io/terratest/modules/aws"
	//fit "github.com/rancher/terraform-aws-rke2/tests/fixtures"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/google/go-github/v53/github"
	"github.com/gruntwork-io/terratest/modules/git"
  "github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSimple(t *testing.T) {
  t.Parallel()
  id := os.Getenv("IDENTIFIER")
  if id == "" {
		id = random.UniqueId()
  }
  id = id + "-" + random.UniqueId()
  directory := "simple"
  region    := "us-west-2"
  owner     := "terraform-ci@suse.com"
	testDir, dataDir, err := getTestDirectory(t,directory,id)
	require.NoError(t, err)
  terraformOptions, keyPair := setup(t, id, testDir, dataDir, region, owner)
	terraformOptions.Vars["zone"] = os.Getenv("ZONE")
	terraformOptions.Vars["rke2_version"] = getLatestRelease(t,"rancher","rke2")
  sshAgent := ssh.SshAgentWithKeyPair(t, keyPair.KeyPair)
  defer sshAgent.Stop()
  terraformOptions.SshAgent = sshAgent
	defer teardown(t, directory, id, keyPair)
  defer terraform.Destroy(t, terraformOptions)
  _, err = terraform.InitAndApplyE(t, terraformOptions)
  if err != nil {
    terraform.Destroy(t, terraformOptions)
		teardown(t, directory, id, keyPair)
    t.Fatalf("Error creating cluster: %s", err)
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
		terraform.Destroy(t, terraformOptions)
		teardown(t, directory, id, keyPair)
		t.Fatalf("Error unmarshalling Json: %v", err)
  }
	kubeconfig := data.Kubeconfig.Value
  assert.NotEmpty(t, kubeconfig)
  if kubeconfig == "{}" {
		terraform.Destroy(t, terraformOptions)
		teardown(t, directory, id, keyPair)
		t.Fatal("Kubeconfig not found")
  }
	kubeconfigPath := dataDir + "/kubeconfig"
  os.WriteFile(kubeconfigPath,[]byte(kubeconfig),0644)
	simpleCheckReady(t, kubeconfigPath)
}

func setup(t *testing.T, uniqueID string, testDir string, dataDir string, region string, owner string) (*terraform.Options, *aws.Ec2Keypair) {

	// Create an EC2 KeyPair that we can use for SSH access
	keyPairName := fmt.Sprintf("terraform-%s", uniqueID)
	keyPair := aws.CreateAndImportEC2KeyPair(t, region, keyPairName)

	// tag the key pair so we can find in the access module
	client, err1 := aws.NewEc2ClientE(t, region)
	require.NoError(t, err1)

	input := &ec2.DescribeKeyPairsInput{
		KeyNames: []*string{a.String(keyPairName)},
	}
	result, err2 := client.DescribeKeyPairs(input)
	require.NoError(t, err2)

	aws.AddTagsToResource(t, region, *result.KeyPairs[0].KeyPairId, map[string]string{"Name": keyPairName, "Owner": owner})

	retryableTerraformErrors := map[string]string{
		// The reason is unknown, but eventually these succeed after a few retries.
		".*unable to verify signature.*":             "Failed due to transient network error.",
		".*unable to verify checksum.*":              "Failed due to transient network error.",
		".*no provider exists with the given name.*": "Failed due to transient network error.",
		".*registry service is unreachable.*":        "Failed due to transient network error.",
		".*connection reset by peer.*":               "Failed due to transient network error.",
		".*TLS handshake timeout.*":                  "Failed due to transient network error.",
	}

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: testDir,
		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{
			"key":        keyPair.KeyPair.PublicKey,
			"key_name":   keyPairName,
			"identifier": uniqueID,
		},
		// Environment variables to set when running Terraform
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
			"TF_DATA_DIR":        dataDir,
		},
		RetryableTerraformErrors: retryableTerraformErrors,
	})
	return terraformOptions, keyPair
}

func teardown(t *testing.T, test string, id string, keyPair *aws.Ec2Keypair) {
	var err error
	testDir, dataDir, err := getTestDirectory(t,test,id)
	files, err := filepath.Glob(testDir + "/.terraform*")
	require.NoError(t, err)
	for _, f := range files {
		err = os.RemoveAll(f)
		require.NoError(t, err)
	}
	files, err = filepath.Glob(testDir + "/terraform.*")
	require.NoError(t, err)
	for _, f := range files {
		err := os.RemoveAll(f)
		require.NoError(t, err)
	}

	err = os.RemoveAll(dataDir)
	require.NoError(t, err)

	aws.DeleteEC2KeyPair(t, keyPair)
}

func getTestDirectory(t *testing.T,name string, id string) (string, string, error) {
  var err error
  wd, err := os.Getwd()
  if err != nil {
    return "","",err
  }
  fwd, err := filepath.Abs(wd)
  if err != nil {
    return "", "", err
  }
  gwd := git.GetRepoRoot(t)
  exampleDir := gwd + "/examples/" + name
  tdd := fwd + "/data/" + id
  err = os.Mkdir(tdd, 0755)
  if err != nil {
    return "", "", err
  }
  testDataDirectory, err := filepath.Abs(tdd)
  if err != nil {
    return "", "", err
  }
  dataDir := testDataDirectory
  return exampleDir, dataDir, nil
}

func simpleCheckReady(t *testing.T, kubeconfigPath string){
  script, err2 := os.ReadFile("./scripts/readyNodes.sh")
  if err2 != nil {
    require.NoError(t, err2)
  }
  readyScript := shell.Command{
    Command: "bash",
    Args: []string{"-c", string(script)},
    Env: map[string]string{
      "KUBECONFIG": kubeconfigPath,
    },
  }
  out := shell.RunCommandAndGetOutput(t, readyScript) // if the script fails, it will fail the test
  t.Logf("Ready script output: %s", out)
}

func getLatestRelease(t *testing.T, owner string, repo string) string {
  ghClient := github.NewClient(nil)
  release, _, err := ghClient.Repositories.GetLatestRelease(context.Background(), owner, repo)
  require.NoError(t, err)
  version := *release.TagName
  return version
}
