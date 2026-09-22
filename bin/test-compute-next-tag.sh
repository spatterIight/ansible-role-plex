#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Plex 1.43.3 which has already seen two
# releases of it (v1.43.3-0 and v1.43.3-1), plus the `v3.14.6-0` tag this
# repository really carries: the commit-message-driven workflow read Renovate's
# "Update python Docker tag to v3.14.6" subject as a Plex version and published
# it. It must not be counted as a release of anything.
#
# The defaults file deliberately carries the traps this role's real one has:
# the `# renovate:` annotation, `plex_version_environment_variable` (which
# starts with the same 12 characters as `plex_version`), and an image tag
# derived from the version. None of them may be picked up as the version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# renovate: datasource=docker depName=ghcr.io/linuxserver/plex versioning=semver
		plex_version: 1.43.3
		plex_arch: amd64
		plex_version_environment_variable: docker
		plex_container_image_tag: "{{ plex_version }}"
	YAML
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v3.14.6-0 v1.43.3-0 v1.43.3-1; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^plex_version: 1.43.3|plex_version: 1.43.4|' defaults/main.yml"
revert_version="sed -i 's|^plex_version: 1.43.4|plex_version: 1.43.3|' defaults/main.yml"
change_version_env="sed -i 's|^plex_version_environment_variable: docker|plex_version_environment_variable: latest|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v1.43.4-0 "$(merge "$bump_version")"
expect 'task edit'    v1.43.4-1 "$(merge "$edit_task")"
expect 'template'     v1.43.4-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v1.43.3-2 "$(merge "$edit_task")"
expect 'version bump' v1.43.4-0 "$(merge "$bump_version")"

# `v3.14.6-0` exists in every scenario, left over from the commit-message era.
# It belongs to no Plex version and must never be treated as one.
scenario 'The bogus tag left over from the commit-message era'
expect 'a task' v1.43.3-2 "$(merge "$edit_task")"

# `plex_version_environment_variable` shares its first 12 characters with
# `plex_version`, so a laxer expression would read `docker` as the version and
# produce a `vdocker-0` tag.
scenario 'The version-like variable that is not the version'
expect 'version environment variable' v1.43.3-2 "$(merge "$change_version_env")"

scenario 'Commits that do not affect the role'
expect 'README'   ''         "$(merge "$edit_readme")"
expect 'a script' ''         "$(merge "$edit_script")"
expect 'a task'   v1.43.3-2  "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v1.43.3-$release_number"
done
expect 'a task' v1.43.3-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v1.43.3-1 already published, so there is
# nothing new to release.
expect 'a revert' ''         "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v1.43.3-2 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
