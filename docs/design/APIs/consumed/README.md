# Consumed Interfaces

Descriptions of the interfaces this artifact consumes: machine-readable ones, such as OpenAPI,
AsyncAPI, Protobuf, or DBC files, and the datasheets of the components it uses. Pin the version:
update the description when the provider releases a new one.

An interface can be referred to in three ways:

- **The file itself**, copied into this directory, when no other source is reachable.
- **A `*.url.txt` file** holding the URL and version of a description published elsewhere.
- **A `*.path.txt` file** holding the relative path to an interface in the same repository:
  another artifact's `docs/design/APIs/provided/` or, in a mono-repository, the shared
  interfaces at the repository root in `docs/design/APIs/`. A path cannot drift the
  way a copy or a URL can.

This file is written by `repo update`; keep notes in another file.
