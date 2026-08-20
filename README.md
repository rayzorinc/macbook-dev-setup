# macbook-dev-setup

Provision a current macOS laptop with SRE and developer tools.
It installs Apple Command Line Tools, Homebrew, Ansible, and a curated set of
current Homebrew formulae and casks.

## What it installs

- Core: Ansible, AWS CLI, current Bash, Git, GitHub CLI, current Go and Python,
  `ag`, `htop`, `jq`, `yq`, `ripgrep`, and `tmux`.
- SRE: Argo CD, EKS authentication and tooling, Fastly CLI, herdr, Kubernetes
  CLI tools, Helm, Podman, Terraform and related utilities, Packer, Vault,
  SOPS, and the `vegeta` and `wrk` HTTP load-testing tools.
- Applications: Codex, Discord, Ghostty, Google Chrome, Slack, Spotify, and
  VLC.

The formula names `go`, `python`, and `terraform` intentionally track the
current Homebrew releases rather than pinning an old workstation image.
Homebrew Bash is installed alongside macOS's system Bash; the setup does not
change a user's login shell.

## Install

```bash
git clone https://github.com/rayzorinc/macbook-dev-setup.git
cd macbook-dev-setup
./bootstrap.sh
```

The script may open Apple's Command Line Tools installer on a fresh Mac. When
that completes, rerun it. Homebrew may also require its standard post-install
PATH instruction before a rerun.

To preview Ansible changes after bootstrap:

```bash
ansible-playbook -i localhost, playbook.yml --check
```

## Podman on macOS

Podman on macOS runs Linux containers in a managed virtual machine. The
playbook installs the CLI but deliberately does not create or start a VM, since
that is local runtime state with user-selected resource limits. Initialize it
after provisioning:

```bash
podman machine init
podman machine start
podman info
```

## Verification

GitHub Actions runs the Linux syntax and repository-safety checks on every
push and pull request. The `macOS Homebrew smoke check` workflow is manual; it
resolves the declared taps, formulae, and casks on a clean macOS runner without
installing them. Run it after changing the package lists.

For a full installation test, use a fresh Mac user or disposable macOS machine
and run `./bootstrap.sh`.

## Deliberate exclusions

This repository must never contain or manage credentials, personal identity, or
employer-specific configuration. It does not copy or configure:

- AWS profiles, SSO sessions, access keys, or `aws-vault` data
- Kubernetes contexts, cluster credentials, or VPN configuration
- SSH keys, Git user name/email, shell history, or dotfiles
- Private Homebrew taps, corporate packages, or tools such as Kraken

After provisioning, authenticate each tool through the approved identity and
secrets workflow for the environment you are joining.

## Maintenance

Add only broadly useful tools to `group_vars/all.yml`. Keep
tool installation declarative through the `community.general` Homebrew modules;
do not add a machine-specific package dump.
