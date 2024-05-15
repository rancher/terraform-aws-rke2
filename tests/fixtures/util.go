package fixtures

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"

	a "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ec2"
	git "github.com/go-git/go-git/v5"
	"github.com/google/go-github/v53/github"
	aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	"golang.org/x/oauth2"
)

func GenerateOptions(t *testing.T,d *FixtureData)(*terraform.Options){

	retryableTerraformErrors := map[string]string{
		// The reason is unknown, but eventually these succeed after a few retries.
		".*unable to verify signature.*":             "Failed due to transient network error.",
		".*unable to verify checksum.*":              "Failed due to transient network error.",
		".*no provider exists with the given name.*": "Failed due to transient network error.",
		".*registry service is unreachable.*":        "Failed due to transient network error.",
		".*connection reset by peer.*":               "Failed due to transient network error.",
		".*TLS handshake timeout.*":                  "Failed due to transient network error.",
	}

	var opt = terraform.Options{
		TerraformDir: d.ExampleDirectory,
		RetryableTerraformErrors: retryableTerraformErrors,
		NoColor: true,
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

func rma(t *testing.T, path string){
	err := os.RemoveAll(path)
	require.NoError(t, err)
}

func GetLatestRelease(t *testing.T, owner string, repo string) string {
	ghClient := github.NewClient(nil)
	release, _, err := ghClient.Repositories.GetLatestRelease(context.Background(), owner, repo)
	require.NoError(t, err)
	version := *release.TagName
	return version
}

func GenerateKey(t *testing.T, d *FixtureData)(*aws.Ec2Keypair) {
	keyPairName := fmt.Sprintf("tf-%s", d.Id)
	keyPair := aws.CreateAndImportEC2KeyPair(t, d.Region, keyPairName)
	// tag the key pair so we can find in the access module
	client, err1 := aws.NewEc2ClientE(t, d.Region)
	require.NoError(t, err1)

	result, err2 := client.DescribeKeyPairs(&ec2.DescribeKeyPairsInput{KeyNames: []*string{a.String(keyPairName)},})
	require.NoError(t, err2)
	aws.AddTagsToResource(t, d.Region, *result.KeyPairs[0].KeyPairId, map[string]string{"Name": keyPairName})
	os.WriteFile(d.DataDirectory + "/ssh_key",[]byte(keyPair.PrivateKey),0600)
	return keyPair
}

func GenerateSshAgent(t *testing.T,d *FixtureData)(*ssh.SshAgent) {
	return ssh.SshAgentWithKeyPair(t, d.SshKeyPair.KeyPair)
}

func GetRke2Releases() (string, string, error) {
	releases, err := getRke2Releases()
	if err != nil {
			return "", "", err
	}

	var versions []string
	for _, release := range releases {
			version := release.GetTagName()
			if !release.GetPrerelease() {
					versions = append(versions, version)
			}
	}

	if len(versions) == 0 {
		return "", "", errors.New("no eligible versions found")
	}

	sort.Slice(versions, func(i, j int) bool {
		return compareVersion(versions[i], versions[j])
	})

	latest := versions[0]
	stable := latest
	if len(versions) > 1 {
			stable = versions[1]
	}

	return latest, stable, nil
}

func compareVersion(v1, v2 string) bool {
	s1 := strings.Split(v1[1:], "+")//["1.30.1","rke2r3"]
	s2 := strings.Split(v2[1:], "+")

	r1 := strings.Split(s1[1], "r")//["rke2", "3"]
	r2 := strings.Split(s2[1], "r")

	s1Parts := strings.Split(s1[0], ".")//["1","30","1"]
	s2Parts := strings.Split(s2[0], ".")

	s1P := append(s1Parts, r1[1]) //["1","30","1","3"]
	s2P := append(s2Parts, r2[1])

	for i := range len(s1P) {
		if s1P[i] != s2P[i] {
				return s1P[i] > s2P[i]
		}
	}
	return s1P[0] > s2P[0]
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
	if err!= nil {
		return nil, err
	}

	return releases, nil
}

// get the Git root for the given directory
func GetGitRoot(dir string) (string, error) {
	repo, err := git.PlainOpen(dir)
	if err != nil {
			return "", err
	}

	// Get the worktree to access the filesystem
	worktree, err := repo.Worktree()
	if err != nil {
			return "", err
	}

	// Get the absolute path of the worktree
	absPath := worktree.Filesystem.Root()
	return absPath, nil
}
