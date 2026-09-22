<!--
SPDX-FileCopyrightText: 2018-2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## What the suite can and cannot tell you

Plex Media Server is proprietary software, and that puts a hard ceiling on what an automated suite is allowed to claim.

**A Plex server has to be claimed to a Plex account to be of any use**, and claiming needs a `PLEX_CLAIM` token from <https://plex.tv/claim>. Those tokens are bound to a person's Plex account. GitHub CI runners cannot hold one, and this role's scenario does not pretend otherwise: every run leaves an **unclaimed** server, and `verify.yml` asserts that it is unclaimed (`claimed="0"` on `/identity`).

Everything which requires the Plex account is therefore out of scope: signing in, adding libraries, scanning media, metadata agents, transcoding (hardware or otherwise), and so on.

What an unclaimed server *does* do turns out to be enough to test the role itself. Run by hand before any of this was written, `ghcr.io/linuxserver/plex` starts, serves HTTP on 32400 and answers `/identity` without authentication, with both the running version and the server's `machineIdentifier`.

Here is a list of what a successful run proves:

- **The pinned version is the running one**: `/identity` reports a four-component Plex version (`1.43.3.10896-cb3ebc72d`) while the linuxserver.io tag the role pins has three (`1.43.3`), so the pinned value is matched as a prefix with a trailing dot. The container's image reference is checked against `plex_version` as well.
- **The server being probed is the one the role deployed**: Plex writes its `machineIdentifier` into `Library/Application Support/Plex Media Server/Preferences.xml` under `/config`. The scenario reads that file from the host, through `plex_data_path`, and asserts it matches what `/identity` returned.
- **The role's configuration reaches the process**: `PUID`, `PGID`, `TZ` and `VERSION` are checked in the container's environment, and the timezone is read back from inside the container as a UTC offset. The files Plex creates are checked to be owned by `plex_uid`:`plex_gid`, which are deliberately neither `root` nor the `1000` the image defaults to.
- **The container is built the way the role's variables say**: The published ports (deliberately different numbers from the container ports, so a dropped variable publishes nothing), the read-only root filesystem and its `tmpfs` `/run`, the data and media bind mounts, `plex_container_additional_volumes` (read back from inside the container, because an entry that is silently dropped looks exactly like one that worked), `plex_container_additional_networks`, `plex_container_extra_arguments` and `plex_container_labels_additional_labels`.
- **The Traefik labels describe what was deployed** — hostname, path prefix, both path-prefix middlewares and the load balancer port — and that `templates/labels.j2` emits *nothing* Traefik-related when `plex_container_labels_traefik_enabled` is `false`.
- **`plex_claim_token` is plumbed through**: No real token exists here, so `templates/env.j2` is rendered out of band with a stand-in value and checked to produce a `PLEX_CLAIM` line, while the env file the role really wrote is checked to contain no `PLEX_CLAIM` at all — an empty `PLEX_CLAIM=` is not the same thing as none.

What it does not prove:

- **Upgrade works**: The scenario always starts from an empty `/config`. Plex migrates its library database in place on the first start of a new build, and nothing here has a library to migrate. This is why patch-level Renovate updates are not automerged; see `.github/renovate.json`.
- **`plex_container_http_port` can be changed**: Plex Media Server always listens on 32400 inside the container.
- **anything about GPU transcoding.** `plex_gpu_bind_path`, `plex_container_runtime` and `plex_nvidia_visible_devices` need hardware the GitHub CI runners do not have.

## Scenarios

Currently there is one testing scenario available.

### `default`

A standard Plex installation, with Traefik labels, a media bind mount, an additional volume, an additional container network, extra container arguments and additional labels all switched on, so that each of those code paths is exercised rather than merely defaulted away.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
