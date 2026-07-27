package fixtures

import (
	"cmp"
	"context"

	// "encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/google/go-github/v53/github"
	aws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	gossh "golang.org/x/crypto/ssh"
	"golang.org/x/oauth2"
)

// GenerateOptions is a helper function to generate terraform options.
func GenerateOptions(t *testing.T, d *FixtureData) *terraform.Options {

	retryableTerraformErrors := map[string]string{
		// The reason is unknown, but eventually these succeed after a few retries.
		".*unable to verify signature.*":                                           "Failed due to transient network error.",
		".*unable to verify checksum.*":                                            "Failed due to transient network error.",
		".*no provider exists with the given name.*":                               "Failed due to transient network error.",
		".*registry service is unreachable.*":                                      "Failed due to transient network error.",
		".*connection reset by peer.*":                                             "Failed due to transient network error.",
		".*TLS handshake timeout.*":                                                "Failed due to transient network error.",
		".*ssh: handshake failed:.*":                                               "Failed due to transient network error.",
		".*Repository 'leap-oss' is invalid.*":                                     "Failed due to transient network error.",
		".*curl.*exit status 55.*":                                                 "Failed due to transient network error.",
		".*curl.*exit status 56.*":                                                 "Failed due to transient network error.",
		".*curl.*exit status 7.*":                                                  "Failed due to transient network error.",
		".*destroy\\.go.*Error: disassociating EC2 EIP.*does not exist.*":          "Failed to delete EIP because interface is already gone",
		".*destroy\\.go.*Error: modifying EC2 Network Interface.*does not exist.*": "Failed to delete non existent interface",
		".*error executing .*destroy.* wait: remote command.*":                     "Failed to wait while deleting",
	}

	var opt = terraform.Options{
		TerraformDir:             d.ExampleDirectory,
		RetryableTerraformErrors: retryableTerraformErrors,
		NoColor:                  true,
	}
	return terraform.WithDefaultRetryableErrors(t, &opt)
}

// Teardown is a helper function to destroy terraform resources.
func Teardown(t *testing.T, f *FixtureData) {
	t.Log("Tearing down...")
	if os.Getenv("DIRTY_MODE") == "true" {
		t.Log("[DIRTY MODE] Skipping Teardown to preserve infrastructure")
		return
	}
	if os.Getenv("DRY_RUN") == "true" || (os.Getenv("HALF_DRY") == "true" && !strings.HasSuffix(f.ExampleDirectory, "test_relay")) {
		t.Log("[DRY RUN / HALF DRY] Skipping Teardown / Terraform destroy")
		return
	}
	if f.TfOptions != nil {
		_, err := terraform.InitContextE(t, t.Context(), f.TfOptions)
		if err != nil {
			t.Logf("Failed to validate: %s", err)
		}

		_, err = terraform.DestroyContextE(t, t.Context(), f.TfOptions)
		if err != nil {
			t.Logf("Failed to destroy: %s", err)
		}
	}
	if f.SSHAgent != nil {
		suppressPanic(f.SSHAgent.Stop)
	}
	if f.SSHKeyPair != nil {
		aws.DeleteEC2KeyPairContext(t, t.Context(), f.SSHKeyPair)
	}
	rma(t, fmt.Sprintf("%s/data/%s", f.ExampleDirectory, f.ID))
	rm(t, fmt.Sprintf("%s/tf-*", f.ExampleDirectory))
	rm(t, fmt.Sprintf("%s/50-*.yaml", f.ExampleDirectory))
	rm(t, fmt.Sprintf("%s/.terraform.lock.hcl", f.ExampleDirectory))

	rma(t, f.DataDirectory)
}

func suppressPanic(f func()) {
	defer func() { _ = recover() }()
	f()
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

// GenerateKey generates a new ssh keypair for the test fixture.
func GenerateKey(t *testing.T, d *FixtureData) (*aws.Ec2Keypair, error) {
	var err error
	keyPairName := fmt.Sprintf("tf-%s", d.ID)
	keyPair := aws.CreateAndImportEC2KeyPairContext(t, t.Context(), d.Region, keyPairName)
	client, err := aws.NewEc2ClientContextE(t, t.Context(), d.Region)
	require.NoError(t, err)
	k := "key-name"
	keyNameFilter := types.Filter{
		Name:   &k,
		Values: []string{keyPairName},
	}
	input := &ec2.DescribeKeyPairsInput{
		Filters: []types.Filter{keyNameFilter},
	}
	result, err := client.DescribeKeyPairs(t.Context(), input)
	require.NoError(t, err)
	require.NotEmpty(t, result.KeyPairs)

	err = aws.AddTagsToResourceContextE(t, t.Context(), d.Region, *result.KeyPairs[0].KeyPairId, map[string]string{"Name": keyPairName, "Owner": d.Owner})
	require.NoError(t, err)

	// Verify that the name and owner tags were placed properly
	k = "tag:Name"
	keyNameFilter = types.Filter{
		Name:   &k,
		Values: []string{keyPairName},
	}
	input = &ec2.DescribeKeyPairsInput{
		Filters: []types.Filter{keyNameFilter},
	}
	result, err = client.DescribeKeyPairs(t.Context(), input)
	require.NoError(t, err)
	require.NotEmpty(t, result.KeyPairs)

	k = "tag:Owner"
	keyNameFilter = types.Filter{
		Name:   &k,
		Values: []string{d.Owner},
	}
	input = &ec2.DescribeKeyPairsInput{
		Filters: []types.Filter{keyNameFilter},
	}
	result, err = client.DescribeKeyPairs(t.Context(), input)
	require.NoError(t, err)
	require.NotEmpty(t, result.KeyPairs)

	err = os.WriteFile(d.DataDirectory+"/ssh_key", []byte(keyPair.PrivateKey), 0600)
	if err != nil {
		return nil, err
	}
	return keyPair, nil
}

// GenerateSSHAgent generates a new ssh agent for the test fixture.
func GenerateSSHAgent(t *testing.T, d *FixtureData) *ssh.SSHAgent {
	return ssh.SSHAgentWithKeyPair(t, t.Context(), d.SSHKeyPair.KeyPair)
}

// GetRke2Releases returns the latest, stable, and lts rke2 releases.
func GetRke2Releases(t *testing.T) (string, string, string, error) {
	releases, err := getRke2Releases(t)
	if err != nil {
		return "", "", "", err
	}
	t.Logf("RKE2 releases found: %v", len(releases))
	versions := filterPrerelease(t, releases)
	if len(versions) == 0 {
		return "", "", "", errors.New("no eligible versions found")
	}
	t.Logf("Eligible versions found: %v", len(versions))
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

func getRke2Releases(t *testing.T) ([]*github.RepositoryRelease, error) {

	githubToken := os.Getenv("GITHUB_TOKEN")
	if githubToken == "" {
		fmt.Println("GITHUB_TOKEN environment variable not set")
		return nil, errors.New("GITHUB_TOKEN environment variable not set")
	}

	// Create a new OAuth2 token using the GitHub token
	tokenSource := oauth2.StaticTokenSource(&oauth2.Token{AccessToken: githubToken})
	tokenClient := oauth2.NewClient(t.Context(), tokenSource)

	// Create a new GitHub client using the authenticated HTTP client
	client := github.NewClient(tokenClient)

	t.Log("Getting rke2 GitHub releases")
	var releases []*github.RepositoryRelease
	var response *github.Response
	var err error

	maxRetries := 10
	baseDelay := time.Second

	for i := range maxRetries {
		releases, response, err = client.Repositories.ListReleases(t.Context(), "rancher", "rke2", &github.ListOptions{Page: 1, PerPage: 100})

		if err == nil && len(releases) > 0 {
			t.Logf("GitHub Response status: %s", response.Status)
			t.Logf("GitHub Rke2 Releases found: %v", len(releases))
			break
		}

		if err != nil {
			t.Logf("Error fetching releases (attempt %d/%d): %v", i+1, maxRetries, err)
		} else {
			t.Logf("No releases found (attempt %d/%d), retrying...", i+1, maxRetries)
		}

		if i < maxRetries-1 {
			sleepDuration := baseDelay * time.Duration(1<<i)
			t.Logf("Sleeping for %v before next attempt...", sleepDuration)
			time.Sleep(sleepDuration)
		}
	}

	if err != nil && len(releases) == 0 {
		return nil, fmt.Errorf("failed to fetch releases after %d attempts: %w", maxRetries, err)
	}

	return releases, nil
}

func filterPrerelease(t *testing.T, r []*github.RepositoryRelease) []string {
	t.Logf("Releases to filter: %v", len(r))
	var versions []string
	for _, release := range r {
		version := release.GetTagName()
		if !release.GetPrerelease() {
			versions = append(versions, version)
			// [
			//   "v1.28.14+rke2r1",
			//   "v1.30.1+rke2r3",
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
		vp := strings.Split(v[1:], "+") // ["1.30.1","rke2r3"]
		pp := strings.Split(p[1:], "+") // ["1.30.1","rke2r2"]
		if vp[0] != pp[0] {
			vpp := strings.Split(vp[0], ".") // ["1","30","1"]
			ppp := strings.Split(pp[0], ".") // ["1","30","1"]
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

func getRepoRoot(ctx context.Context, _ *testing.T) (string, error) {
	cmd := exec.CommandContext(ctx, "git", "rev-parse", "--show-toplevel")
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to locate git repo root: %w", err)
	}
	return strings.TrimSpace(string(out)), nil
}

// CreateFixture creates a new test fixture.
func CreateFixture(t *testing.T, combo map[string]string) (string, string, FixtureData, error) {
	root, err := getRepoRoot(t.Context(), t)
	if err != nil {
		return "", "", FixtureData{}, err
	}
	repoRoot, err := filepath.Abs(root)
	if err != nil {
		return "", "", FixtureData{}, err
	}

	var fixtureData FixtureData
	fixtureData.ID = getID()
	fixtureData.Name = combo["fixture"]
	fixtureData.InstallType = combo["installType"]
	fixtureData.OperatingSystem = combo["operatingSystem"]
	fixtureData.Release = combo["release"]
	fixtureData.Cni = combo["cni"]
	fixtureData.IPFamily = combo["ipFamily"]
	fixtureData.Owner = "terraform-ci@suse.com"
	fixtureData.DataDirectory = repoRoot + "/test/data/" + fixtureData.ID
	fixtureData.Region = getRegion()
	fixtureData.AcmeServer = getAcmeServer()
	fixtureData.Zone = os.Getenv("ZONE")

	err = createTestDirectories(t, fixtureData.ID)
	if err != nil {
		return "", "", fixtureData, err
	}

	repoZip := os.Getenv("TEST_REPO_ZIP")
	insideRelay := os.Getenv("INSIDE_RELAY") == "true"

	if repoZip != "" && !insideRelay {
		// ----------------------------------------------------
		// LOCAL ORCHESTRATOR MODE (SSH test runner)
		// ----------------------------------------------------
		fixtureData.ExampleDirectory = repoRoot + "/test/test_relay"

		latest, stable, old, err := GetRke2Releases(t)
		if err != nil {
			return "", "", fixtureData, err
		}
		comboName := getComboName(&fixtureData, latest, stable, old)

		if os.Getenv("DRY_RUN") == "true" {
			t.Logf("[DRY RUN] Skipping test_relay deployment and remote SSH execution for combo %s", comboName)
			return "skip_kubeconfig", "skip_api", fixtureData, nil
		}

		// Deploy test_relay
		_, _, err = create(t, &fixtureData)
		if err != nil {
			t.Errorf("Error creating test relay: %v", err)
			return "", "", fixtureData, err
		}

		runnerIP, err := terraform.OutputContextE(t, t.Context(), fixtureData.TfOptions, "runner_ip")
		if err != nil {
			return "", "", fixtureData, err
		}
		username, err := terraform.OutputContextE(t, t.Context(), fixtureData.TfOptions, "username")
		if err != nil {
			return "", "", fixtureData, err
		}

		host := ssh.Host{
			Hostname:    runnerIP,
			SshUserName: username,
			SshKeyPair:  fixtureData.SSHKeyPair.KeyPair,
		}

		t.Logf("Executing remote test for %s on runner %s...", comboName, runnerIP)

		// Step 1: Decrypt secrets on the host
		decryptCommand := fmt.Sprintf(
			"age -d -i /home/%s/age_key /home/%s/secrets.rc.age > /home/%s/workspace/secrets.rc",
			username, username, username,
		)
		t.Logf("[STEP 1] Decrypting environment secrets on host...")
		_, err = ssh.CheckSSHCommandContextE(t, t.Context(), &host, decryptCommand)
		if err != nil {
			t.Errorf("Remote secrets decryption failed: %v", err)
			return "", "", fixtureData, err
		}

		// Step 2: Run containerized tests (utilizing host networking for native DNS and zero virtualization overhead)
		testCommand := fmt.Sprintf("bash ./run_tests.sh -f %s --inside-relay --identifier %s -n 5", comboName, fixtureData.ID)
		if os.Getenv("HALF_DRY") == "true" {
			testCommand += " --dry-run"
		}

		dockerCommand := fmt.Sprintf(
			"sudo docker run --rm "+
				"--network host "+
				"-v /home/%s/workspace:/workspace "+
				"-v /var/run/docker.sock:/var/run/docker.sock "+
				"-w /workspace "+
				"ghcr.io/rancher/ci-image/nix:20260603-18 "+
				"bash .github/workflows/scripts/nix-run.sh \"%s\"",
			username, testCommand,
		)
		t.Logf("[STEP 2] Launching Nix containerized test execution: %s", testCommand)
		_, err = runSSHCommandStream(t, &host, dockerCommand)

		// Step 3: Securely cleanup secrets.rc file (always executed)
		t.Logf("[STEP 3] Cleaning up temporary secrets...")
		cleanupCommand := fmt.Sprintf("rm -f /home/%s/workspace/secrets.rc", username)
		_, _ = ssh.CheckSSHCommandContextE(t, t.Context(), &host, cleanupCommand)

		if err != nil {
			t.Errorf("Remote test execution failed for combination %s: %v", comboName, err)
			return "", "", fixtureData, err
		}

		t.Logf("✓ Remote test execution succeeded for combination %s!", comboName)
		// Return "skip" values so the local orchestrator knows it was successful and skips checkReady locally
		return "skip_kubeconfig", "skip_api", fixtureData, nil
	}

	// ----------------------------------------------------
	// REMOTE TEST MODE / DIRECT DEPLOYMENT
	// ----------------------------------------------------
	fixtureData.ExampleDirectory = repoRoot + "/examples/" + fixtureData.Name

	if os.Getenv("DRY_RUN") == "true" || os.Getenv("HALF_DRY") == "true" {
		t.Logf("[DRY RUN / HALF DRY] Skipping direct deployment for fixture %s", fixtureData.Name)
		return "dry_run_kubeconfig", "dry_run_api", fixtureData, nil
	}

	kubeconfig, api, err := create(t, &fixtureData)
	if err != nil {
		t.Errorf("Error creating fixture: %v", err)
		return "", "", fixtureData, err
	}
	if kubeconfig == "{}" {
		t.Log("Kubeconfig not found")
		return "", "", fixtureData, errors.New("kubeconfig not found")
	}
	if api == "" {
		t.Log("API not found")
		return "", "", fixtureData, errors.New("api not found")
	}
	err = os.WriteFile(fixtureData.DataDirectory+"/kubeconfig", []byte(kubeconfig), 0600)
	if err != nil {
		return "", "", fixtureData, err
	}
	t.Logf("API is %s", api)
	return fixtureData.DataDirectory + "/kubeconfig", api, fixtureData, nil
}

func getAcmeServer() string {
	acmeserver := os.Getenv("ACME_SERVER_URL")
	if acmeserver == "" {
		acmeserver = "https://acme-staging-v02.api.letsencrypt.org/directory"
		if err := os.Setenv("ACME_SERVER_URL", acmeserver); err != nil {
			panic(err)
		}
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

func getID() string {
	id := os.Getenv("IDENTIFIER")
	if id == "" {
		id = random.UniqueID()
	}
	id += "-" + random.UniqueID()
	return id
}

func createTestDirectories(t *testing.T, id string) error {
	gwd, err := getRepoRoot(t.Context(), t)
	if err != nil {
		return err
	}
	fwd, err := filepath.Abs(gwd)
	if err != nil {
		return err
	}
	dataDir := "/test/data/"
	tdd := fwd + dataDir
	err = os.Mkdir(tdd, 0750)
	if err != nil && !os.IsExist(err) {
		return err
	}
	tdd = fwd + dataDir + id
	err = os.Mkdir(tdd, 0750)
	if err != nil && !os.IsExist(err) {
		return err
	}
	tdd = fwd + dataDir + id + "/test"
	err = os.Mkdir(tdd, 0750)
	if err != nil && !os.IsExist(err) {
		return err
	}
	tdd = fwd + dataDir + id + "/install"
	err = os.Mkdir(tdd, 0750)
	if err != nil && !os.IsExist(err) {
		return err
	}
	return nil
}

func getComboName(d *FixtureData, latest, stable, old string) string {
	release := d.Release
	switch release {
	case latest:
		release = "latest"
	case stable:
		release = "stable"
	case old:
		release = "old"
	}
	parts := []string{
		d.OperatingSystem,
		d.Cni,
		release,
		d.Name,
		d.InstallType,
		d.IPFamily,
	}
	return strings.Join(parts, "-")
}

func runSSHCommandStream(t *testing.T, host *ssh.Host, command string) (string, error) {
	// Parse the private key to create an SSH Signer
	signer, err := gossh.ParsePrivateKey([]byte(host.SshKeyPair.PrivateKey))
	if err != nil {
		return "", fmt.Errorf("failed to parse private key: %w", err)
	}

	// Configure the standard SSH Client
	config := &gossh.ClientConfig{
		User: host.SshUserName,
		Auth: []gossh.AuthMethod{
			gossh.PublicKeys(signer),
		},
		// #nosec G106
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
		Timeout:         30 * time.Second,
	}

	// Connect to the remote host
	address := fmt.Sprintf("%s:%d", host.Hostname, host.GetPort())
	client, err := gossh.Dial("tcp", address, config)
	if err != nil {
		return "", fmt.Errorf("failed to dial SSH: %w", err)
	}
	defer func() {
		_ = client.Close()
	}()

	// Create an SSH Session
	session, err := client.NewSession()
	if err != nil {
		return "", fmt.Errorf("failed to create SSH session: %w", err)
	}
	defer func() {
		_ = session.Close()
	}()

	// Redirect Stdout and Stderr to stream in real-time
	writer := &terratestLogWriter{t: t}
	session.Stdout = writer
	session.Stderr = writer

	t.Logf("Running remote command with live streaming: %s", command)
	err = session.Run(command)
	return "", err
}

type terratestLogWriter struct {
	t *testing.T
}

func (w *terratestLogWriter) Write(p []byte) (n int, err error) {
	// Write to os.Stdout so it shows up live in the terminal
	_, _ = os.Stdout.Write(p)
	return len(p), nil
}
