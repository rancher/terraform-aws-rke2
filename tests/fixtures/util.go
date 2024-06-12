package fixtures

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/google/go-github/v53/github"
	aws "github.com/gruntwork-io/terratest/modules/aws"
	g "github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	"golang.org/x/oauth2"
)

func GenerateOptions(t *testing.T, d *FixtureData) *terraform.Options {

	retryableTerraformErrors := map[string]string{
		// The reason is unknown, but eventually these succeed after a few retries.
		".*unable to verify signature.*":                    "Failed due to transient network error.",
		".*unable to verify checksum.*":                     "Failed due to transient network error.",
		".*no provider exists with the given name.*":        "Failed due to transient network error.",
		".*registry service is unreachable.*":               "Failed due to transient network error.",
		".*connection reset by peer.*":                      "Failed due to transient network error.",
		".*TLS handshake timeout.*":                         "Failed due to transient network error.",
		".*Error: disassociating EC2 EIP.*does not exist.*": "Failed to delete EIP because interface is already gone",
	}

	var opt = terraform.Options{
		TerraformDir:             d.ExampleDirectory,
		RetryableTerraformErrors: retryableTerraformErrors,
		NoColor:                  true,
	}
	return terraform.WithDefaultRetryableErrors(t, &opt)
}

func Teardown(t *testing.T, f *FixtureData) {
	f.SshAgent.Stop()
	terraform.Destroy(t, f.TfOptions)
	aws.DeleteEC2KeyPair(t, f.SshKeyPair)
	rma(t, fmt.Sprintf("%s/.terraform", f.ExampleDirectory))
	rma(t, fmt.Sprintf("%s/rke2", f.ExampleDirectory))
	rma(t, fmt.Sprintf("%s/tmp", f.ExampleDirectory))
	rma(t, fmt.Sprintf("%s/terraform.tfstate", f.ExampleDirectory))
	rma(t, fmt.Sprintf("%s/terraform.tfstate.backup", f.ExampleDirectory))
	rm(t, fmt.Sprintf("%s/kubeconfig-*.yaml", f.ExampleDirectory))
	rm(t, fmt.Sprintf("%s/tf-*", f.ExampleDirectory))
	rm(t, fmt.Sprintf("%s/50-*.yaml", f.ExampleDirectory))
	if t.Failed() {
		t.Logf("Test failed, not cleaning up test directory %s", f.DataDirectory)
		return
	}
	rma(t, f.DataDirectory)
}

func rm(t *testing.T, path string) {
	files, err := filepath.Glob(path)
	require.NoError(t, err)
	for _, file := range files {
		err2 := os.RemoveAll(file)
		require.NoError(t, err2)
	}
}

func rma(t *testing.T, path string) {
	err := os.RemoveAll(path)
	require.NoError(t, err)
}

func GenerateKey(t *testing.T, d *FixtureData) (*aws.Ec2Keypair, error) {
	var err error
	keyPairName := fmt.Sprintf("tf-%s", d.Id)
	keyPair := aws.CreateAndImportEC2KeyPair(t, d.Region, keyPairName)
	client, err := aws.NewEc2ClientE(t, d.Region)
	require.NoError(t, err)
	k := "key-name"
	keyNameFilter := ec2.Filter{
		Name:   &k,
		Values: []*string{&keyPairName},
	}
	input := &ec2.DescribeKeyPairsInput{
		Filters: []*ec2.Filter{&keyNameFilter},
	}
	result, err := client.DescribeKeyPairs(input)
	require.NoError(t, err)
	require.NotEmpty(t, result.KeyPairs)

	err = aws.AddTagsToResourceE(t, d.Region, *result.KeyPairs[0].KeyPairId, map[string]string{"Name": keyPairName, "Owner": d.Owner})
	require.NoError(t, err)

	// Verify that the name and owner tags were placed properly
	k = "tag:Name"
	keyNameFilter = ec2.Filter{
		Name:   &k,
		Values: []*string{&keyPairName},
	}
	input = &ec2.DescribeKeyPairsInput{
		Filters: []*ec2.Filter{&keyNameFilter},
	}
	result, err = client.DescribeKeyPairs(input)
	require.NoError(t, err)
	require.NotEmpty(t, result.KeyPairs)

	k = "tag:Owner"
	keyNameFilter = ec2.Filter{
		Name:   &k,
		Values: []*string{&d.Owner},
	}
	input = &ec2.DescribeKeyPairsInput{
		Filters: []*ec2.Filter{&keyNameFilter},
	}
	result, err = client.DescribeKeyPairs(input)
	require.NoError(t, err)
	require.NotEmpty(t, result.KeyPairs)

	os.WriteFile(d.DataDirectory+"/ssh_key", []byte(keyPair.PrivateKey), 0600)
	return keyPair, err
}

func GenerateSshAgent(t *testing.T, d *FixtureData) *ssh.SshAgent {
	return ssh.SshAgentWithKeyPair(t, d.SshKeyPair.KeyPair)
}

func GetRke2Releases() (string, string, string, error) {
	releases, err := getRke2Releases()
	if err != nil {
		return "", "", "", err
	}
	versions := filterPrerelease(releases)
	if len(versions) == 0 {
		return "", "", "", errors.New("no eligible versions found")
	}
	sortVersions(&versions)
	v := filterDuplicateMinors(versions)
	latest := v[0]
	stable := latest
	lts := stable
	if len(v) > 1 {
		stable = v[1]
	}
	if len(v) > 2 {
		lts = v[2]
	}
	return latest, stable, lts, nil
}

func getRke2Releases() ([]*github.RepositoryRelease, error) {

	githubToken := os.Getenv("GITHUB_TOKEN")
	if githubToken == "" {
		fmt.Println("GITHUB_TOKEN environment variable not set")
		return nil, errors.New("GITHUB_TOKEN environment variable not set")
	}

	// Create a new OAuth2 token using the GitHub token
	tokenSource := oauth2.StaticTokenSource(&oauth2.Token{AccessToken: githubToken})
	tokenClient := oauth2.NewClient(context.Background(), tokenSource)

	// Create a new GitHub client using the authenticated HTTP client
	client := github.NewClient(tokenClient)

	var releases []*github.RepositoryRelease
	releases, _, err := client.Repositories.ListReleases(context.Background(), "rancher", "rke2", &github.ListOptions{})
	if err != nil {
		return nil, err
	}

	return releases, nil
}
func filterPrerelease(r []*github.RepositoryRelease) []string {
	var versions []string
	for _, release := range r {
		version := release.GetTagName()
		if !release.GetPrerelease() {
			versions = append(versions, version)
			// [
			//    "v1.28.14+rke2r1",
			//    "v1.30.1+rke2r3",
			//   "v1.29.4+rke2r1",
			//   "v1.30.1+rke2r2",
			//   "v1.29.5+rke2r2",
			//   "v1.30.1+rke2r1",
			//   "v1.27.20+rke2r1",
			//   "v1.30.0+rke2r1",
			//   "v1.29.5+rke2r1",
			//   "v1.28.17+rke2r1",
			// ]
		}
	}
	return versions
}
func sortVersions(v *[]string) {
	slices.SortFunc(*v, func(a, b string) int {
		return cmp.Compare(b, a)
		//[
		//  v1.30.1+rke2r3,
		//  v1.30.1+rke2r2,
		//  v1.30.1+rke2r1,
		//  v1.30.0+rke2r1,
		//  v1.29.5+rke2r2,
		//  v1.29.5+rke2r1,
		//  v1.29.4+rke2r1,
		//  v1.28.17+rke2r1,
		//  v1.28.14+rke2r1,
		//  v1.27.20+rke2r1,
		//]
	})
}
func filterDuplicateMinors(vers []string) []string {
	var fv []string
	fv = append(fv, vers[0])
	for i := 1; i < len(vers); i++ {
		p := vers[i-1]
		v := vers[i]
		vp := strings.Split(v[1:], "+") //["1.30.1","rke2r3"]
		pp := strings.Split(p[1:], "+") //["1.30.1","rke2r2"]
		if vp[0] != pp[0] {
			vpp := strings.Split(vp[0], ".") //["1","30","1]
			ppp := strings.Split(pp[0], ".") //["1","30","1]
			if vpp[1] != ppp[1] {
				fv = append(fv, v)
				//[
				//  v1.30.1+rke2r3,
				//  v1.29.5+rke2r2,
				//  v1.28.17+rke2r1,
				//  v1.27.20+rke2r1,
				//]
			}
		}
	}
	return fv
}

func CreateFixture(t *testing.T, combo map[string]string) (string, FixtureData, error) {
	repoRoot, err := filepath.Abs(g.GetRepoRoot(t))
	if err != nil {
		return "", FixtureData{}, err
	}

	var fixtureData FixtureData
	fixtureData.Id = getId()
	fixtureData.Name = combo["fixture"]
	fixtureData.InstallType = combo["installType"]
	fixtureData.OperatingSystem = combo["operatingSystem"]
	fixtureData.Release = combo["release"]
	fixtureData.Cni = combo["cni"]
	fixtureData.IpFamily = combo["ipFamily"]
	fixtureData.IngressController = combo["ingressController"]
	fixtureData.Owner = "terraform-ci@suse.com"
	fixtureData.ExampleDirectory = repoRoot + "/examples/" + fixtureData.Name
	fixtureData.DataDirectory = repoRoot + "/tests/test/data/" + fixtureData.Id
	fixtureData.Region = getRegion()
	fixtureData.AcmeServer = getAcmeServer()
	fixtureData.Zone = os.Getenv("ZONE")

	err = createTestDirectories(t, fixtureData.Id)
	if err != nil {
		return "", fixtureData, err
	}

	kubeconfig := create(t, &fixtureData)
	if kubeconfig == "{}" {
		t.Log("Kubeconfig not found")
		return "", fixtureData, errors.New("kubeconfig not found")
	}
	os.WriteFile(fixtureData.DataDirectory+"/kubeconfig", []byte(kubeconfig), 0644)

	return fixtureData.DataDirectory + "/kubeconfig", fixtureData, nil
}

func getAcmeServer() string {
	acmeserver := os.Getenv("ACME_SERVER_URL")
	if acmeserver == "" {
		os.Setenv("ACME_SERVER_URL", "https://acme-staging-v02.api.letsencrypt.org/directory")
	}
	return acmeserver
}

func getRegion() string {
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = os.Getenv("AWS_DEFAULT_REGION")
	}
	if region == "" {
		region = "us-west-2"
	}
	return region
}

func getId() string {
	id := os.Getenv("IDENTIFIER")
	if id == "" {
		id = random.UniqueId()
	}
	id += "-" + random.UniqueId()
	return id
}

func createTestDirectories(t *testing.T, id string) error {
	gwd := g.GetRepoRoot(t)
	fwd, err := filepath.Abs(gwd)
	if err != nil {
		return err
	}
	tdd := fwd + "/tests/test/data"
	err = os.Mkdir(tdd, 0755)
	if err != nil && !os.IsExist(err) {
		return err
	}
	tdd = fwd + "/tests/test/data/" + id
	err = os.Mkdir(tdd, 0755)
	if err != nil && !os.IsExist(err) {
		return err
	}
	tdd = fwd + "/tests/test/data/" + id + "/test"
	err = os.Mkdir(tdd, 0755)
	if err != nil && !os.IsExist(err) {
		return err
	}
	tdd = fwd + "/tests/test/data/" + id + "/install"
	err = os.Mkdir(tdd, 0755)
	if err != nil && !os.IsExist(err) {
		return err
	}
	return nil
}
