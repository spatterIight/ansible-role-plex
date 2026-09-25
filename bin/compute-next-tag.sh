#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<Plex version>-<release>`, which is what this repository has
# always published (v1.41.6-0 ... v1.43.3-0):
#
# - if defaults/main.yml points at a Plex version that has never been released,
#   the release counter restarts at 0 (`v1.43.4-0`)
# - otherwise the counter is incremented (`v1.43.4-1`), but only if something
#   that actually affects the role has changed since the last release
#
# Determining the version from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.
#
# It also avoids the failure modes of the commit-message-driven workflow this
# replaced, which scanned the last 20 commits for a `renovate[bot]` subject
# containing "docker tag to ":
#
# - on 2026-06-11 it read Renovate's "Update python Docker tag to v3.14.6"
#   subject - a bump of the `.python-version` used by the Molecule CI job - as
#   a Plex version and published `v3.14.6-0` off it, while defaults/main.yml
#   said 1.43.2 all along. The `v3.14.6-0` tag is still there. Four days later
#   a `"$subject" == *"plex"*` filter was bolted on, which stops that one
#   spelling and nothing else
# - a hand-written version bump is never released at all, because no commit by
#   `renovate[bot]` matches
# - once more than 20 commits have piled up on top of a bump, the bump becomes
#   invisible and its release is lost for good
# - the tag is attached to the Renovate commit rather than to the tip, so
#   anything merged after the bump is silently left out of the release

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration, Molecule tests)
# does not change what a playbook run does, and releasing it would only create
# churn in the repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

# Anchored at the start of the line and requiring the colon immediately after
# the variable name, so that neither the `# renovate:` annotation directly
# above the variable, nor `plex_version_environment_variable` (which starts
# with the same 12 characters), nor `plex_container_image_tag` (which is
# derived from it) can be picked up instead.
version="$(sed -nE 's|^plex_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the Plex version from $defaults_path"
	exit 1
fi

# The version value carries no leading `v` (e.g. `1.43.3`), while the tags
# always have had one. The stripping keeps this correct either way.
tag_prefix="v${version#v}-"

# Of all releases of this version, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
