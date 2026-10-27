"""Builds the docs site from docs/, grouped by the question a document answers.

Run by the mkdocs-gen-files plugin (see mkdocs.yml). docs_dir is docs/, served at the root of the
site. At the root of a mono-repository, extra.artifacts of mkdocs.yml lists the artifacts; the
docs/ of each is added below the artifact's directory name.

The script
- fails the build on a file directly in a docs/ other than index.md,
- adds a page for each feature file, API description, and attachment,
- rewrites a relative link between two docs/ directories to the path of its target on the site,
- adds the combined glossary of a mono-repository, and
- builds the navigation: one section per group, each directory a closed subsection.
"""

import posixpath
import re
from pathlib import Path

import mkdocs_gen_files
from mkdocs.exceptions import PluginError

CONFIG = mkdocs_gen_files.config
ROOT = Path(CONFIG["config_file_path"]).parent
GROUPS = ("requirements", "design", "verification", "manuals")
NOT_IN_NAV = ("_media", "assets")
PICTURES = (".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp")
LINK = re.compile(r"(\]\()([^)\s]+)(\))")
ARTIFACTS = CONFIG["extra"].get("artifacts") or []
EXCLUDED = CONFIG["exclude_docs"]


def title(name: str) -> str:
    """Returns the title of a directory: underscores become spaces, an acronym keeps its capitals."""
    text = name.replace("_", " ")
    return text[:1].upper() + text[1:]


def site_path(repo_path: str) -> str | None:
    """Returns the path on the site of a path in the repository, or None if the site lacks it."""
    if repo_path == "docs" or repo_path.startswith("docs/"):
        return repo_path.removeprefix("docs").removeprefix("/")
    for artifact in ARTIFACTS:
        directory = artifact["dir"]
        if repo_path == directory or repo_path == f"{directory}/docs":
            return f"{directory}/"
        if repo_path.startswith(f"{directory}/docs/"):
            return directory + "/" + repo_path.removeprefix(f"{directory}/docs/")
    return None


def site_link(repo_page: str, target: str) -> str:
    """Returns a link of the page at repo_page as seen from that page's place on the site."""
    if "://" in target or target.startswith(("/", "#", "mailto:")):
        return target
    path, hash_, fragment = target.partition("#")
    resolved = posixpath.normpath(posixpath.join(posixpath.dirname(repo_page), path))
    on_site = site_path(resolved)
    if on_site is None:
        return target
    here = posixpath.dirname(site_path(repo_page) or "")
    link = posixpath.relpath(on_site.rstrip("/") or ".", here or ".")
    if path.endswith("/") or on_site.endswith("/"):
        link += "/"
    return link + hash_ + fragment


def with_site_links(repo_page: str, text: str) -> str:
    return LINK.sub(lambda m: m.group(1) + site_link(repo_page, m.group(2)) + m.group(3), text)


def check_top_level(docs: Path) -> None:
    """Fails the build on a file or directory directly in docs other than index.md and the groups."""
    allowed = {"index.md", *GROUPS, *NOT_IN_NAV}
    for entry in sorted(docs.iterdir()):
        if entry.name.startswith(".") or entry.name in allowed:
            continue
        raise PluginError(
            f"{entry.relative_to(ROOT).as_posix()}: docs/ holds index.md and the directories "
            f"{', '.join(g + '/' for g in GROUPS)} only. Move it into the directory whose "
            "question it answers."
        )


def feature_page(repo_path: str, text: str) -> str:
    """Shows a feature file, linking the Capability Specification it is named like, if it exists."""
    name = re.search(r"^\s*Feature:\s*(.+)$", text, re.M)
    stem = Path(repo_path).stem
    lines = [f"# {name.group(1).strip() if name else stem}", ""]
    parts = repo_path.split("/")
    docs_dir = "/".join(parts[: parts.index("docs") + 1])
    spec = f"{docs_dir}/requirements/capabilities/{stem}.md"
    if (ROOT / spec).is_file():
        target = posixpath.relpath(spec, posixpath.dirname(repo_path))
        lines += [f"Derived from [{stem}.md]({site_link(repo_path, target)}).", ""]
    return "\n".join(lines + ["````gherkin", text.rstrip(), "````", ""])


def api_page(source: Path, text: str) -> str:
    """Shows an API description: OpenAPI in Swagger UI, any other as a code block."""
    if source.suffix in (".yaml", ".yml") and "openapi:" in text[:512]:
        return f'# {source.stem}\n\n<swagger-ui src="{source.name}"/>\n'
    language = "protobuf" if source.suffix == ".proto" else "yaml"
    return f"# {source.stem}\n\n````{language}\n{text.rstrip()}\n````\n"


def write(page: str, content: str, source: Path) -> None:
    with mkdocs_gen_files.open(page, "w") as f:
        f.write(content)
    mkdocs_gen_files.set_edit_path(page, source.relative_to(ROOT).as_posix())


def add_tree(docs: Path, prefix: str, native: bool) -> set[str]:
    """Adds the files of docs below prefix, and returns the pages; native files exist already."""
    pages = set()
    sources = sorted(p for p in docs.rglob("*") if p.is_file() and not p.name.startswith("."))
    present = {p.relative_to(docs).with_suffix(".md").as_posix() for p in sources if p.suffix == ".md"}
    for source in sources:
        rel = source.relative_to(docs).as_posix()
        repo_path = source.relative_to(ROOT).as_posix()
        page = prefix + rel
        if EXCLUDED and EXCLUDED.match_file(page):
            continue
        if source.suffix == ".md":
            text = source.read_text(encoding="utf-8")
            rewritten = with_site_links(repo_path, text)
            if not native or rewritten != text:
                write(page, rewritten, source)
            pages.add(page)
            continue
        if not native and source.suffix != ".feature":
            with mkdocs_gen_files.open(page, "wb") as f:
                f.write(source.read_bytes())
        if rel.split("/", 1)[0] in NOT_IN_NAV or source.suffix in PICTURES:
            continue
        own = source.relative_to(docs).with_suffix(".md").as_posix()
        if own in present:
            continue
        if source.suffix == ".feature":
            content = feature_page(repo_path, source.read_text(encoding="utf-8"))
        elif source.suffix in (".yaml", ".yml", ".proto"):
            content = api_page(source, source.read_text(encoding="utf-8"))
        else:
            content = f"# {source.name}\n\n[{source.name}]({source.name})\n"
        write(prefix + own, content, source)
        present.add(own)
        pages.add(prefix + own)
    return pages


def nav_of(directory: str, pages: set[str]) -> list:
    """Returns the navigation of the pages below directory: index.md first, the section's start
    page, then files, then each subdirectory as a section."""
    files = sorted(p for p in pages if posixpath.dirname(p) == directory)
    files.sort(key=lambda p: posixpath.basename(p) != "index.md")
    subdirectories = sorted({p[len(directory) + 1:].split("/", 1)[0] for p in pages
                             if p.startswith(directory + "/") and posixpath.dirname(p) != directory})
    return files + [{title(d): nav_of(f"{directory}/{d}", pages)} for d in subdirectories]


def groups_of(prefix: str, pages: set[str]) -> list:
    return [{title(g): nav_of(prefix + g, pages)} for g in GROUPS
            if any(p.startswith(prefix + g + "/") for p in pages)]


def glossary_rows(path: Path, origin: str) -> list[tuple[str, str, str]]:
    rows = []
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if line.lstrip().startswith("|") and len(cells) >= 2 and cells[0] not in ("Term", "") \
                    and not set(cells[0]) <= set("-: "):
                rows.append((cells[0], cells[1], origin))
    return rows


def combined_glossary() -> str:
    """Returns the glossary of the root and every artifact, sorted; an identical entry once."""
    entries: dict[tuple[str, str], list[str]] = {}
    sources = [(ROOT / "docs/requirements/glossary.md", "System")]
    sources += [(ROOT / a["dir"] / "docs/requirements/glossary.md", a["title"]) for a in ARTIFACTS]
    for path, origin in sources:
        for term, definition, where in glossary_rows(path, origin):
            entries.setdefault((term, definition), []).append(where)
    lines = ["# Combined Glossary", "",
             "Every term of the system and its artifacts, with where it is defined.", "",
             "| Term | Definition | Defined in |", "| --- | --- | --- |"]
    for (term, definition), where in sorted(entries.items(), key=lambda e: e[0][0].lower()):
        lines.append(f"| {term} | {definition} | {', '.join(where)} |")
    return "\n".join(lines) + "\n"


check_top_level(ROOT / "docs")
root_pages = add_tree(ROOT / "docs", "", native=True)
root_pages.discard("index.md")
if not ARTIFACTS:
    CONFIG["nav"] = [{"Overview": "index.md"}, *groups_of("", root_pages)]
else:
    with mkdocs_gen_files.open("requirements/combined_glossary.md", "w") as f:
        f.write(combined_glossary())
    root_pages.add("requirements/combined_glossary.md")
    nav = [{"Overview": "index.md"}, {"System": groups_of("", root_pages)}]
    for artifact in ARTIFACTS:
        docs = ROOT / artifact["dir"] / "docs"
        if not docs.is_dir():
            continue
        check_top_level(docs)
        prefix = artifact["dir"] + "/"
        pages = add_tree(docs, prefix, native=False)
        index = [prefix + "index.md"] if prefix + "index.md" in pages else []
        nav.append({artifact["title"]: index + groups_of(prefix, pages)})
    CONFIG["nav"] = nav
