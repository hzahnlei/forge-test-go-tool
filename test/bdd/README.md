# BDD Test Suite

Godog scenarios for this tool live in `docs/verification/acceptance/`, derived from the acceptance
criteria of the _Capability Specifications_ in `docs/requirements/capabilities/`. Add `.feature`
files there and implement their steps in `InitializeScenario` (`bdd_test.go`). `TestMain` builds the
tool once; each scenario runs the binary as a user would.
