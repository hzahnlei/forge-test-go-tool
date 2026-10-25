package main

import "gitlab.com/hzahnlei/go-tool/cmd"

// version is set at build time via -ldflags in Makefile.
var version = "0.0.0"

func main() {
	cmd.SetVersion(version)
	cmd.Execute()
}
