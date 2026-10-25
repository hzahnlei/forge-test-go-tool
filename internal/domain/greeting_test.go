package domain_test

import (
	"testing"

	"gitlab.com/hzahnlei/go-tool/internal/domain"
)

func TestGreet(t *testing.T) {
	tests := []struct {
		name string
		want string
	}{
		{"World", "Hello, World!"},
		{"Alice", "Hello, Alice!"},
	}
	for _, tt := range tests {
		if got := domain.Greet(tt.name); got != tt.want {
			t.Errorf("Greet(%q) = %q, want %q", tt.name, got, tt.want)
		}
	}
}
