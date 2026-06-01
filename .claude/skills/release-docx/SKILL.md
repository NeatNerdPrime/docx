---
name: release-docx
description: Cut a new release of the ruby-docx/docx gem. Use when the user wants to release, ship, publish, or tag a new version (e.g. "let's release", "リリースしちゃおう", "cut v0.13.0"). Bumps the version, pushes a tag, and lets GitHub Actions build the GitHub Release and publish to RubyGems.
---

# Release the docx gem

Releasing ruby-docx/docx is **tag-driven**: pushing a `vX.Y.Z` tag triggers
`.github/workflows/release.yml`, which builds the gem (`rake build`), creates a
GitHub Release with auto-generated notes, and publishes to RubyGems via OIDC
trusted publishing (`rubygems/release-gem@v1`). No manual gem push or credentials.

## Before you start

- **Confirm the version number with the user.** Publishing to RubyGems is
  effectively irreversible (you can only `gem yank`, not delete). Never guess.
- **Pick the version by semver.** A new public method/API (e.g. a new
  `Paragraph#substitute`) is a **minor** bump, not a patch. Pure bug fixes are a
  patch. Breaking changes are a major. State your recommendation when asking.
- Confirm what is unreleased: `git log --oneline vLAST..HEAD | grep 'Merge pull request'`.

## Steps

1. Make sure local `master` matches origin:
   ```sh
   git switch master && git fetch origin master && git merge --ff-only origin/master
   ```
2. Bump the version in `lib/docx/version.rb` (`VERSION = 'X.Y.Z'`).
3. Commit **directly to master** (no PR — this is the established pattern) with
   the exact conventional message, then push:
   ```sh
   git add lib/docx/version.rb
   git commit -m "Bump up the version to vX.Y.Z"
   git push origin master
   ```
4. Tag and push the tag — **this is the trigger**:
   ```sh
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
5. Watch the release workflow to completion:
   ```sh
   run_id=$(gh run list --repo ruby-docx/docx --workflow release.yml --branch vX.Y.Z --limit 1 --json databaseId --jq '.[0].databaseId')
   gh run watch "$run_id" --repo ruby-docx/docx --exit-status
   ```
6. Verify both outputs:
   ```sh
   gh release view vX.Y.Z --repo ruby-docx/docx --json tagName,isDraft,body
   curl -s https://rubygems.org/api/v1/versions/docx/latest.json   # expect {"version":"X.Y.Z"}
   ```

## Notes

- **Do NOT touch `CHANGELOG.md`** — it has been stale since v0.7.0; the
  GitHub auto-generated release notes are the source of truth.
- Auto-generated notes credit each PR's title and its author. To get an original
  contributor's handle into the notes, that handle must already be in the **PR
  title** (the notes credit only the PR opener, who is the maintainer). So this
  is decided at PR-creation time, not here.
- Two workflow runs fire on the bump (one for the `master` push, one for the
  tag). The **tag** run is the one that does the actual release (its `release`
  job is gated on `refs/tags/`).
- If the run fails after the tag is pushed, inspect with
  `gh run view <id> --repo ruby-docx/docx --log-failed`, fix forward, and re-tag
  (e.g. a patch bump) — the bump commit and tag already exist.
