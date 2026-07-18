#!/usr/bin/env python3
"""Update a pinned Agent Skills repository hosted on GitHub."""

from __future__ import annotations

import argparse
import contextlib
import difflib
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path
from typing import TYPE_CHECKING, NoReturn
from urllib.error import URLError
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parent))
from update_support import HTTPS_CONTEXT

if TYPE_CHECKING:
    from collections.abc import Sequence


GITHUB_API_VERSION = "2022-11-28"
HTTP_USER_AGENT = "nix-conf-updater/1.0 (+https://github.com/NixOS/nixpkgs)"
REVISION_PATTERN = re.compile(r"[0-9a-f]{40}")
SOURCE_PATTERN = re.compile(
    r'^\{\n  version = "[^"]+";\n  src = \{\n'
    r'    owner = "(?P<owner>[^"]+)";\n'
    r'    repo = "(?P<repo>[^"]+)";\n'
    r'    rev = "(?P<rev>[0-9a-f]+)";\n'
    r'    hash = "(?P<hash>sha256-[^"]+)";\n'
    r"  \};\n\}\n$"
)


def _fail(message: str) -> NoReturn:
    sys.stderr.write(f"error: {message}\n")
    raise SystemExit(1)


def _fetch_latest_commit(owner: str, repo: str) -> tuple[str, date]:
    url = f"https://api.github.com/repos/{owner}/{repo}/commits/main"
    request = Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": HTTP_USER_AGENT,
            "X-GitHub-Api-Version": GITHUB_API_VERSION,
        },
    )
    try:
        with urlopen(request, timeout=30, context=HTTPS_CONTEXT) as response:
            payload = json.load(response)
    except URLError as exc:
        _fail(f"failed to fetch {owner}/{repo} main branch: {exc}")

    if not isinstance(payload, dict):
        _fail("GitHub commit response was not an object")
    revision = payload.get("sha")
    commit = payload.get("commit")
    if not isinstance(revision, str) or REVISION_PATTERN.fullmatch(revision) is None:
        _fail("GitHub commit response did not contain a full SHA-1 revision")
    if not isinstance(commit, dict):
        _fail("GitHub commit response did not contain commit metadata")
    author = commit.get("author")
    if not isinstance(author, dict) or not isinstance(author.get("date"), str):
        _fail("GitHub commit response did not contain an author date")
    try:
        commit_date = date.fromisoformat(author["date"][:10])
    except ValueError as exc:
        _fail(f"GitHub commit date was invalid: {exc}")
    return revision, commit_date


def _prefetch_source(owner: str, repo: str, revision: str) -> str:
    archive_url = f"https://github.com/{owner}/{repo}/archive/{revision}.tar.gz"
    completed = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", "--unpack", archive_url],
        capture_output=True,
        check=False,
        text=True,
    )
    if completed.returncode != 0:
        _fail(completed.stderr.strip() or "failed to prefetch GitHub source archive")
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        _fail(f"failed to parse nix prefetch output: {exc}")
    content_hash = payload.get("hash") if isinstance(payload, dict) else None
    if not isinstance(content_hash, str) or not content_hash.startswith("sha256-"):
        _fail("nix prefetch output did not contain an SRI SHA-256 hash")
    return content_hash


def _render_source(owner: str, repo: str, revision: str, content_hash: str, commit_date: date) -> str:
    return (
        "{\n"
        f'  version = "unstable-{commit_date.isoformat()}";\n'
        "  src = {\n"
        f'    owner = "{owner}";\n'
        f'    repo = "{repo}";\n'
        f'    rev = "{revision}";\n'
        f'    hash = "{content_hash}";\n'
        "  };\n"
        "}\n"
    )


def _write_atomic(path: Path, content: str) -> None:
    file_descriptor, temporary_path = tempfile.mkstemp(prefix=f"{path.name}.", dir=path.parent)
    try:
        os.close(file_descriptor)
        Path(temporary_path).write_text(content, encoding="utf-8", newline="\n")
        Path(temporary_path).replace(path)
    finally:
        with contextlib.suppress(OSError):
            Path(temporary_path).unlink(missing_ok=True)


def main(
    expected_owner: str,
    expected_repo: str,
    package_dir: Path,
    argv: Sequence[str] | None = None,
) -> int:
    """Update one provider's source pin from its GitHub main branch.

    Returns:
        A process-compatible exit code.

    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="print a diff without writing")
    parser.add_argument("--check", action="store_true", help="exit non-zero when an update is available")
    args = parser.parse_args(list(argv) if argv is not None else None)

    source_path = package_dir / "source.nix"
    old_source = source_path.read_text(encoding="utf-8")
    match = SOURCE_PATTERN.fullmatch(old_source)
    if match is None:
        _fail(f"{source_path} has an unexpected format")
    if (match["owner"], match["repo"]) != (expected_owner, expected_repo):
        _fail(f"{source_path} does not pin {expected_owner}/{expected_repo}")

    revision, commit_date = _fetch_latest_commit(expected_owner, expected_repo)
    content_hash = _prefetch_source(expected_owner, expected_repo, revision)
    new_source = _render_source(
        expected_owner,
        expected_repo,
        revision,
        content_hash,
        commit_date,
    )
    if new_source == old_source:
        print(f"[update] {expected_owner}/{expected_repo} is already up to date")
        return 0

    sys.stdout.write(
        "".join(
            difflib.unified_diff(
                old_source.splitlines(keepends=True),
                new_source.splitlines(keepends=True),
                fromfile=str(source_path),
                tofile=str(source_path),
            )
        )
    )
    if args.check:
        return 1
    if args.dry_run:
        return 0

    _write_atomic(source_path, new_source)
    print(f"[update] updated {expected_owner}/{expected_repo}")
    return 0
