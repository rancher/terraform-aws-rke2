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

	a "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ec2"
	git "github.com/go-git/go-git/v5"
	"github.com/google/go-github/v53/github"
	aws "github.com/gruntwork-io/terratest/modules/aws"
	g "github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/random"
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
  rm(t,  fmt.Sprintf("%s/kubeconfig-*.yaml", f.ExampleDirectory))
  rm(t,  fmt.Sprintf("%s/tf-*", f.ExampleDirectory))
  rm(t,  fmt.Sprintf("%s/50-*.yaml", f.ExampleDirectory))
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
  lts    := stable
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
  if err!= nil {
    return nil, err
  }

  return releases, nil
}
func filterPrerelease(r []*github.RepositoryRelease ) ([]string) {
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
    return cmp.Compare(b,a)
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
func filterDuplicateMinors(vers []string) ([]string) {
  var fv []string
  fv = append(fv,vers[0])
  for i:=1;i<len(vers);i++ {
    p  := vers[i-1]
    v  := vers[i]
    vp := strings.Split(v[1:], "+")//["1.30.1","rke2r3"]
    pp := strings.Split(p[1:], "+")//["1.30.1","rke2r2"]
    if vp[0] != pp[0] {
      vpp := strings.Split(vp[0], ".")//["1","30","1]
      ppp := strings.Split(pp[0], ".")//["1","30","1]
      if vpp[1] != ppp[1] {
        fv = append(fv,v)
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

func CreateFixture(t *testing.T, combo map[string]string) (string, FixtureData, error) {
  var fixtureData FixtureData
  fixtureData.Name = combo["fixture"]
  fixtureData.InstallType = combo["installType"]
  fixtureData.OperatingSystem = combo["operatingSystem"]
  fixtureData.Release = combo["release"]
  fixtureData.Cni = combo["cni"]
  fixtureData.IpFamily = combo["ipFamily"]
  fixtureData.IngressController = combo["ingressController"]
  fixtureData.ExampleDirectory = g.GetRepoRoot(t) + "/examples/" + fixtureData.Name
  setFixtureData(t, &fixtureData)
  kubeconfig := create(t,&fixtureData)
  if kubeconfig == "{}" {
    t.Log("Kubeconfig not found")
    return "", fixtureData, errors.New("kubeconfig not found")
  }
  os.WriteFile(fixtureData.DataDirectory + "/kubeconfig",[]byte(kubeconfig),0644)

  return fixtureData.DataDirectory + "/kubeconfig", fixtureData, nil
}

func setFixtureData(t *testing.T, data *FixtureData){
  setId(data)
  setTestDirectory(t, data)
  data.Region = os.Getenv("AWS_REGION")
  if data.Region == "" {
    data.Region = os.Getenv("AWS_DEFAULT_REGION")
  }
  if data.Region == "" {
    data.Region = "us-west-2"
  }
  data.Zone = os.Getenv("ZONE")
  acmeserver := os.Getenv("ACME_SERVER_URL")
  if acmeserver == "" {
    os.Setenv("ACME_SERVER_URL", "https://acme-staging-v02.api.letsencrypt.org/directory")
  }
  data.AcmeServer = acmeserver
}

func setId(f *FixtureData) {
  id := os.Getenv("IDENTIFIER")
  if id == "" {
    id = random.UniqueId()
  }
  id += "-" + random.UniqueId()
  f.Id = id
}

func setTestDirectory(t *testing.T,f *FixtureData) error {
  var err error
  wd, err := os.Getwd()
  if err != nil {
    return err
  }
  fwd, err := filepath.Abs(wd)
  if err != nil {
    return err
  }
  gwd := g.GetRepoRoot(t)
  f.ExampleDirectory = gwd + "/examples/" + f.Name
  tdd := fwd + "/data/" + f.Id
  err = os.Mkdir(tdd, 0755)
  if err != nil {
    return err
  }
  testDataDirectory, err := filepath.Abs(tdd)
  if err != nil {
    return err
  }
  f.DataDirectory = testDataDirectory
  return nil
}
