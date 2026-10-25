package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"gitlab.com/hzahnlei/go-tool/internal/domain"
)

// SetVersion injects the build-time version string into the root command.
func SetVersion(v string) {
	rootCmd.Version = v
}

var rootCmd = &cobra.Command{
	Use:   "go-tool",
	Short: "Go CLI Tool example.",
	RunE: func(cmd *cobra.Command, args []string) error {
		name, _ := cmd.Flags().GetString("name")
		fmt.Println(domain.Greet(name))
		return nil
	},
}

// Execute runs the root command.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func init() {
	rootCmd.Flags().StringP("name", "n", "World", "Optionally: Your name.")
}
