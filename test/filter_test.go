package test

import (
	"fmt"
	"os/exec"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
)

func TestFilter(_ *testing.T) {
	f := types.Filter{}
	fmt.Printf("%T\n", f.Values)
}

func TestRunTestsNoColorHelp(t *testing.T) {
	cmd := exec.CommandContext(t.Context(), "bash", "../run_tests.sh", "--no-color", "--help")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failed to run run_tests.sh: %v. Output:\n%s", err, string(out))
	}

	outputStr := string(out)

	// Verify --no-color is documented in the help output
	if !strings.Contains(outputStr, "--no-color") {
		t.Errorf("Expected help output to contain '--no-color', but got:\n%s", outputStr)
	}

	// Verify the output contains no ANSI escape codes
	if strings.Contains(outputStr, "\x1b[") || strings.Contains(outputStr, "\033[") {
		t.Errorf("Expected output to have no color escape codes, but found ANSI escape sequences in:\n%s", outputStr)
	}
}
