# Input Documents

An _Input Document_ is handed to development, such as a requirements specification, a customer's
use cases, or a standard. Keep it here unchanged, as a reference.

An _Input Document_ is never implemented directly. Translate it into _Capability Specifications_
first, and name it under their References. The assistant reads it only when asked.

## Which Material Goes Where

The test: if a document is still needed once every _Capability Specification_ derived from it is
written, it is no _Input Document_.

| Material | Directory | Why |
| --- | --- | --- |
| Customer requirements, tender documents, requirement lists | `docs/requirements/inputs/` | Raw material for the requirements |
| Notes of workshops and interviews, e-mails of stakeholders | `docs/requirements/inputs/` | Raw material for the requirements |
| Scans of paper forms of the current process | `docs/requirements/inputs/` | Show which data the current process records |
| Screenshots and recordings of a system to be replaced | `docs/requirements/inputs/` | Show what the current system does |
| Sketches, wireframes, and mockups, while they are proposals | `docs/requirements/inputs/` | Raw material for the requirements |
| Process diagrams of a business department | `docs/requirements/inputs/` | Raw material for the requirements |
| Excerpts of standards, laws, and regulations | `docs/requirements/inputs/` | Requirements are derived from them |
| Sample data of a stakeholder, such as an export as JSON or CSV | `docs/requirements/inputs/` | Shows the data as it is today |
| Datasheets of components the system uses | `docs/design/APIs/consumed/` | Describe the interface of a component, binding as long as it is built in |
| Agreed exchange formats, as a schema | `docs/design/APIs/` | Binding interface |
| Agreed mockups | `docs/design/`, or part of a _Capability Specification_ | Binding design |
| Test data | Test code | Used by the tests only |
| Pictures and other media of the project | `docs/_media/` | One place per level, shared by the documents of all groups |
| Large media, such as videos of workshops | Outside the repository, linked from a Markdown file in the directory it belongs to | Every clone would carry large binary files forever. Git LFS, if they must be versioned |

This file is written by `repo update`; keep notes in another file.
