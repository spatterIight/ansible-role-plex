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

**A Plex server has to be claimed to a Plex account to be of any use**, and claiming needs a `PLEX_CLAIM` token from Plex. Those tokens are bound to a person's Plex account. GitHub CI runners cannot hold one, and this role's scenario does not pretend otherwise: every run leaves an **unclaimed** server, and `verify.yml` asserts that it is unclaimed (`claimed="0"` on `/identity`). Everything which requires the Plex account is therefore out of scope.

What an unclaimed server *does* do turns out to be enough to test the role itself. Run by hand before any of this was written, `ghcr.io/linuxserver/plex` starts, serves HTTP on 32400 and answers `/identity` without authentication, with both the running version and the server's `machineIdentifier`.

Here is a synopsis of what a successful run proves. Check the scenario itself for details about what are exactly checked.

- The pinned version is the running one
- The server being probed is the one the role deployed
- The role's configuration reaches the process
- The container is built the way the role's variables say
- The Traefik labels describe what was deployed
- `plex_environment_variables_plex_claim` is plumbed through

What it does not prove:

- If upgrade works
- Anything about GPU transcoding

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
