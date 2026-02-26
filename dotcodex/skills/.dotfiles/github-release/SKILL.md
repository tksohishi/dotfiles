---
name: "github-release"
description: "Release version $ARGUMENTS"
---

Use this skill when the user asks to run `/github-release`.


Release a new version of the current project. If a project-local `/github-release` command exists (`.claude/commands/github-release.md`), defer to it instead.

## Step 1: Determine version

If `$ARGUMENTS` specifies a version (e.g. `1.2.0`, `v1.2.0`), use that. Strip the leading `v` for the version number; use `v`-prefixed form for tags.

If no version argument is provided:

1. Find the latest tag: `git describe --tags --abbrev=0`
2. List commits since that tag: `git log $(git describe --tags --abbrev=0)..HEAD --oneline`
3. Assess what kind of bump is appropriate based on the commits:
   - **Major**: breaking changes (for pre-1.0 projects, breaking changes bump minor instead)
   - **Minor**: new features
   - **Patch**: bug fixes, docs, refactors
4. Present 2-3 version options to the user using AskUserQuestion, with reasoning for each

If there are no existing tags, suggest `0.1.0` or `1.0.0` and ask the user.

## Step 2: Detect project type and bump version

Check for manifest files in the project root and update the version accordingly:

**Swift** (`Package.swift` exists):
- Find and update `Info.plist` using `/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString <version>" <path>/Info.plist`

**Python** (`pyproject.toml` exists):
- Update the `version` field in `pyproject.toml`
- Run `uv sync` if `uv.lock` exists

**Node** (`package.json` exists):
- Update the `version` field in `package.json`
- Do NOT run `npm version` or `pnpm version` (they auto-commit/tag)

**Go** (`go.mod` exists):
- Tag only; Go derives version from git tags

**Other** (Makefile, or version derived from git tags):
- No file updates needed; tag only

If none of the above match, ask the user whether any files need a version update.

## Step 3: Commit version changes

If any files were modified in Step 2:

```
git add <changed files>
git commit -m "Bump version to <version>"
```

Skip this step if no files were changed (tag-only projects).

## Step 4: Tag and push

```
git tag v<version>
git push --follow-tags
```

## Step 5: Create GitHub release

Generate release notes from commits since the previous tag, organized into sections:

- **Breaking Changes** (commits with "breaking", "BREAKING", or "!" in conventional commit type)
- **New Features** (commits with "feat", "add")
- **Fixes** (commits with "fix")
- **Other** (everything else)

Omit empty sections. If categorization is ambiguous, use `--generate-notes` as fallback:

```
gh release create v<version> --generate-notes
```

If you did generate structured notes, pass them via `--notes`:

```
gh release create v<version> --notes "<notes>"
```

## Constraints

- Follow semver; for pre-1.0 projects, minor = breaking
- Never add AI agent as commit author or co-author
- Use plain quoted strings for commit messages
