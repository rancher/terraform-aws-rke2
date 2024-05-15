package test

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	fit "github.com/rancher/terraform-aws-rke2/tests/fixtures"
)

func TestMatrixOne(t *testing.T) {
	// fixtures := []string{"one", "three", "splitRole"}
	// installTypes := []string{"tar", "rpm"}
	fixture := "one"
	operatingSystems := []string{
		"sles-15",
		"sles-15-byos",
		"sles-15-cis",
		"sle-micro-55-ltd",
		"sle-micro-55-byos",
		"rhel-8-cis",
		"ubuntu-20",
		"ubuntu-22",
		"rocky-8",
		"liberty-7",
		"rhel-9",
		"rhel-8",
	}
	releases := getReleases(t)
	if len(releases) == 0 {
		return
	}

	// show basic matrix for OS*release
	// only use the first combo for now, we can expand later
	combinations := combine(operatingSystems,releases)
	for _, combo := range combinations {
		if combo == combinations[0] { //remove this to add all combos
			t.Run((combo[0] + "-" + combo[1]),func(t *testing.T){
				t.Parallel()
				t.Logf("Testing with: OS %s and Release %s", combo[0], combo[1])
				var fixtureData fit.FixtureData
				fixtureData.Name = fixture
				fixtureData.OperatingSystem = combo[0]
				fixtureData.Release = combo[1]
				defer fit.Teardown(t, &fixtureData)
				setFixtureData(t, &fixtureData)
				err := test(t, &fixtureData)
				assert.NoError(t, err)
			})
		}
	}
}

func test(t *testing.T, f *fit.FixtureData) (error){
	kubeconfig := getTestFunc(f.Name)(t,f) // run the function getTestFunc returns
	if kubeconfig == "{}" {
		t.Log("Kubeconfig not found")
		return errors.New("Kubeconfig not found")
	}
	kubeConfigLocation := f.DataDirectory + "/kubeconfig"
	t.Logf("Kubeconfig: %s", kubeconfig)
	os.WriteFile(kubeConfigLocation,[]byte(kubeconfig),0644)
	assert.True(t,checkReady(t,kubeConfigLocation))
	return nil
}

func getTestFunc (f string) func(t *testing.T, f *fit.FixtureData) string {
	switch f {
		case "one": return fit.CreateOne
	}
	return nil
}

func checkReady(t *testing.T, kubeconfig string) (bool) {
	script, err2 := os.ReadFile("./scripts/readyNodes.sh")
	if err2 != nil {
		require.NoError(t, err2)
	}
	readyScript := shell.Command{
		Command: "bash",
		Args: []string{"-c", string(script)},
		Env: map[string]string{
			"KUBECONFIG": kubeconfig,
		},
	}
	out := shell.RunCommandAndGetOutput(t, readyScript)
	t.Logf("CheckReady Output: %s",strings.TrimSpace(out))
	return assert.Equal(t,"",out)
}

func setId(f *fit.FixtureData) {
	id := os.Getenv("IDENTIFIER")
	if id == "" {
		id = random.UniqueId()
	}
	id += "-" + random.UniqueId()
	f.Id = id
}

func setTestDirectory(t *testing.T,f *fit.FixtureData){
	var err error

	wd, err := os.Getwd()
	if err != nil {
		require.NoError(t, err)
		return
	}
	fwd, err := filepath.Abs(wd)
	t.Logf("Current working dir is : %s", fwd)
	if err != nil {
		require.NoError(t, err)
		return
	}
	gwd := git.GetRepoRoot(t)
	t.Logf("Git directory is : %s", gwd)
	if err != nil {
		require.NoError(t, err)
		return
	}
	f.ExampleDirectory = gwd + "/examples/" + f.Name
	t.Logf("Example directory is : %s", f.ExampleDirectory)
	if err != nil {
		require.NoError(t, err)
		return
	}


	tdd := fwd + "/data/" + f.Id
	err = os.Mkdir(tdd, 0755)
	if err != nil {
		require.NoError(t, err)
		return
	}

	testDataDirectory, err := filepath.Abs(tdd)
	t.Logf("Test data directory is : %s", testDataDirectory)
	if err != nil {
		require.NoError(t, err)
		return
	}
	f.DataDirectory = testDataDirectory
}

func getReleases(t *testing.T)([]string){
	latest, stable, err := fit.GetRke2Releases()
	if err != nil {
		require.NoError(t, err)
		return []string{}
	}
	return []string{
		latest,
		stable,
	}
}

func setFixtureData(t *testing.T, data *fit.FixtureData){
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

// Combine generates all possible combinations of two slices of strings.
func combine(slice1, slice2 []string) [][2]string {
	var combinations [][2]string
	for _, item1 := range slice1 {
		for _, item2 := range slice2 {
			combinations = append(combinations, [2]string{item1, item2})
		}
	}
	return combinations
}
