// Package domain contains the technology-agnostic core: entities, value objects, and business
// rules. It performs no I/O and must not import usecase, infra, or app.
package domain

import "fmt"

// Greet returns a greeting string for the given name.
func Greet(name string) string {
	return fmt.Sprintf("Hello, %s!", name)
}
