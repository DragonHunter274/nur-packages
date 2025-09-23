package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"syscall"
)

// Field represents a field in the rbw secret
type Field struct {
	Name  string `json:"name"`
	Value string `json:"value"`
	Type  string `json:"type"`
}

// Secret represents the structure of a secret from rbw
type Secret struct {
	Fields []Field `json:"fields"`
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <executable-name> [args...]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "The executable name is also used as the secret name\n")
		os.Exit(1)
	}

	executable := os.Args[1]
	args := os.Args[2:]

	// Get the secret from rbw
	secret, err := getRbwSecret(executable)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to retrieve secret '%s' from rbw: %v\n", executable, err)
		fmt.Fprintf(os.Stderr, "Make sure the secret exists and rbw is unlocked\n")
		os.Exit(1)
	}

	// Extract environment variables from fields
	envVars := make(map[string]string)
	for _, field := range secret.Fields {
		if field.Name != "executable" && field.Name != "custom-type" {
			envVars[field.Name] = field.Value
		}
	}


	// Run the command with the environment variables
	err = runWithEnv(executable, args, envVars)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to run %s: %v\n", executable, err)
		os.Exit(1)
	}
}

// getRbwSecret retrieves and parses a secret from rbw
func getRbwSecret(secretName string) (*Secret, error) {
	cmd := exec.Command("rbw", "get", "--raw", secretName)
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("rbw command failed: %w", err)
	}

	var secret Secret
	err = json.Unmarshal(output, &secret)
	if err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	return &secret, nil
}

// runWithEnv runs a command with additional environment variables
func runWithEnv(executable string, args []string, envVars map[string]string) error {
	// Find the executable path
	execPath, err := exec.LookPath(executable)
	if err != nil {
		return fmt.Errorf("executable not found: %w", err)
	}

	// Prepare environment variables
	env := os.Environ()
	for key, value := range envVars {
		env = append(env, fmt.Sprintf("%s=%s", key, value))
	}

	// Prepare arguments (first argument should be the program name)
	execArgs := make([]string, len(args)+1)
	execArgs[0] = executable
	copy(execArgs[1:], args)

	// Execute the command, replacing the current process
	err = syscall.Exec(execPath, execArgs, env)
	if err != nil {
		return fmt.Errorf("exec failed: %w", err)
	}

	// This line should never be reached if exec succeeds
	return nil
}
