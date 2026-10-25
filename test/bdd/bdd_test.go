package bdd

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cucumber/godog"
)

// binary is the tool under test, built once by TestMain.
var binary string

// TestMain builds the tool into a temporary directory, so the scenarios run the binary a user runs.
// `make coverage` sets BDD_COVERDIR: the binary is then built with coverage instrumentation and
// writes its counts into BDD_COVERDIR, which `make coverage` adds to the figure of the tests. The
// whole module is instrumented, since Go writes the counts only when package main is instrumented
// too; `make coverage` leaves cmd/ out when it reads them.
func TestMain(m *testing.M) {
	os.Exit(runWithBinary(m))
}

func runWithBinary(m *testing.M) int {
	dir, err := os.MkdirTemp("", "bdd-test")
	if err != nil {
		fmt.Fprintln(os.Stderr, "create build directory:", err)
		return 1
	}
	defer func() {
		if err := os.RemoveAll(dir); err != nil {
			fmt.Fprintln(os.Stderr, "remove build directory:", err)
		}
	}()
	binary = filepath.Join(dir, "go-tool")
	args := []string{"build", "-o", binary}
	if os.Getenv("BDD_COVERDIR") != "" {
		args = append(args, "-cover", "-covermode=atomic", "-coverpkg=gitlab.com/hzahnlei/go-tool/...")
	}
	build := exec.Command("go", append(args, "gitlab.com/hzahnlei/go-tool/cmd/go-tool")...)
	build.Stdout = os.Stderr
	build.Stderr = os.Stderr
	if err := build.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "build go-tool:", err)
		return 1
	}
	return m.Run()
}

// TestFeatures runs every .feature file under docs/verification/acceptance/ through Godog.
func TestFeatures(t *testing.T) {
	suite := godog.TestSuite{
		ScenarioInitializer: InitializeScenario,
		Options: &godog.Options{
			Format:   "pretty",
			Paths:    []string{"../../docs/verification/acceptance"},
			Tags:     "~@integrative && ~@wip",
			TestingT: t,
		},
	}
	if suite.Run() != 0 {
		t.Fatal("non-zero status returned, failed to run feature tests")
	}
}

// bddState holds the input and the tool's output across the steps of one scenario.
// Godog re-initializes it per scenario via InitializeScenario, so scenarios never share state.
type bddState struct {
	name   string
	stdout bytes.Buffer
	stderr bytes.Buffer
	err    error
}

func (s *bddState) aName(name string) error {
	s.name = name
	return nil
}

func (s *bddState) iRunTheToolWithThatName() error {
	run := exec.Command(binary, "--name", s.name)
	if dir := os.Getenv("BDD_COVERDIR"); dir != "" {
		run.Env = append(os.Environ(), "GOCOVERDIR="+dir)
	}
	run.Stdout = &s.stdout
	run.Stderr = &s.stderr
	s.err = run.Run()
	return nil
}

func (s *bddState) itPrints(expected string) error {
	if s.err != nil {
		return fmt.Errorf("tool failed: %w: %s", s.err, s.stderr.String())
	}
	if !strings.Contains(s.stdout.String(), expected) {
		return fmt.Errorf("expected output containing %q, got %q", expected, s.stdout.String())
	}
	return nil
}

func InitializeScenario(ctx *godog.ScenarioContext) {
	state := &bddState{}
	ctx.Given(`^a name "([^"]*)"$`, state.aName)
	ctx.When(`^I run the tool with that name$`, state.iRunTheToolWithThatName)
	ctx.Then(`^it prints "([^"]*)"$`, state.itPrints)
}
