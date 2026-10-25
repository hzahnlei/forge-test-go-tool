# Provided Interfaces

Machine-readable descriptions of the interfaces this artifact provides, such as OpenAPI,
AsyncAPI, Protobuf, or DBC files. Write or update the description before implementing it; it is
the contract.

An interface can be provided in two ways:

- **The file itself**, placed in this directory.
- **A `*.path.txt` file** holding the relative path to an interface shared by several artifacts of
  a mono-repository, kept at the repository root in `docs/design/APIs/`. Use it when
  this artifact implements part of a shared interface, such as its messages in a common DBC file.

This file is written by `repo update`; keep notes in another file.
