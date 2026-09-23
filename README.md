# macbook-dev-setup

[![Validate workstation setup](https://github.com/rayzorinc/macbook-dev-setup/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/rayzorinc/macbook-dev-setup/actions/workflows/validate.yml)

Provision a current macOS laptop with SRE and developer tools.
It installs Apple Command Line Tools, Homebrew, Ansible, and a curated set of
current Homebrew formulae and casks.

## What it installs

Bootstrap installs Apple Command Line Tools, Homebrew, Xcode, Ansible, and the
`community.general` Ansible collection—in that order. Xcode is installed and
selected through `xcodes` after Homebrew is available. Intel Macs install Xcode
26.3, the newest release compatible with macOS 15.8; Apple Silicon Macs install
the latest Xcode release. Xcodes prompts for an Apple ID and any required
two-factor code, storing its authenticated session in the macOS Keychain. The
playbook then installs the following current Homebrew packages.

### Core command-line tools

- `ansible`, `ansible-lint`, `awscli`, `bash`, `bash-completion@2`, `curl`,
  `git`, `gh`, `go`, `gopls`, `htop`, `jq`
- `python`, `ripgrep`, `ruby`, `the_silver_searcher` (`ag`), `tmux`,
  `virtualenv`, `vim`, `yq`

### SRE, cloud, and infrastructure tools

- `argocd`, `aws-iam-authenticator`, `eksctl`, `helm`, `herdr`, `packer`,
  `podman`, `sops`, `vault`
- Kubernetes: `kubernetes-cli` (`kubectl`), `kustomize`, `kubectx`, `kubent`,
  `kubeconform`
- Terraform: `terraform`, `terraform-docs`, `terraformer`, `terragrunt`,
  `terraform-ls`, `tfenv`
- Fastly CLI: `fastly/tap/fastly`
- HTTP load testing: `vegeta`, `wrk`

### Applications

- `codex`, `discord`, `ghostty`, `google-chrome`, `slack`, `spotify`, `vlc`

### Homebrew taps

- `fastly/tap`, `hashicorp/tap`

Homebrew 7 requires explicit trust before it loads formulae from third-party
taps. The playbook trusts only these declared taps before installing their
formulae; other taps remain untrusted.

The formula names `go`, `python`, and `terraform` intentionally track the
current Homebrew releases rather than pinning an old workstation image.
Homebrew Bash is installed alongside macOS's system Bash; the setup does not
change a user's login shell.

Python's standard-library `venv` module is verified by the playbook, and the
standalone `virtualenv` command is installed. Create a project virtual
environment with `python3 -m venv .venv` or `virtualenv .venv`.

## Bash-it and Bash completions

The playbook installs `bash-completion@2`, links completion definitions exposed
by Homebrew commands, and clones Bash-it. It adds clearly marked, idempotent
blocks to `~/.bashrc` and `~/.bash_profile`; these load Homebrew completions and
Bash-it only in interactive Bash shells. Existing dotfile content is retained.

Open a new Bash shell after provisioning, or run `source ~/.bashrc`.

## Vim tooling

The playbook installs Vim and native Vim packages for ALE diagnostics and
completion, Ansible, FZF, NERDTree, snippets, easy alignment, Go, Ruby, and
Terraform. It also installs the matching external tools used by those plugins:
`ansible-lint`, `gopls`, and `terraform-ls`; Ruby syntax checking uses the
installed Ruby interpreter.

The plugins are cloned into `~/.vim/pack/macbook-dev-setup/start`, and the
playbook adds a clearly marked ALE configuration block under
`~/.vim/after/plugin`. It does not modify an existing Vim-Plug plugin list or
copy private/local plugins. Codex has no additional Vim plugin configured; its
Bash completion is generated through the managed Bash completion setup.

## Install

```bash
git clone https://github.com/rayzorinc/macbook-dev-setup.git
cd macbook-dev-setup
./bootstrap.sh
```

The script supports both Intel and Apple Silicon Macs. It automatically loads
Homebrew from `/usr/local` on Intel or `/opt/homebrew` on Apple Silicon, so a
fresh Homebrew install can continue without opening a new shell. The script
may open Apple's Command Line Tools installer on a fresh Mac; when that
completes, rerun it.

On Macs with Command Line Tools already installed, bootstrap checks Apple
Software Update for a newer Command Line Tools package and installs that
package only. It never removes the existing tools or installs unrelated system
updates. If Software Update does not offer the requested version, download its
package from [Apple Developer Downloads](https://developer.apple.com/download/all/)
instead. `xcode-select --install` also uses Apple's Software Update channel,
so it cannot install a specific newer Xcode release that Apple does not offer
there.

The Xcode installation needs administrator approval to select the installed
developer directory and complete Apple’s first-launch setup. Existing Xcode
26.3 installations in `/Applications` are reused on Intel safe reruns. Apple
Silicon bootstrap runs check for the latest Xcode release on every rerun and
selects the highest installed Xcode version. Apple Silicon Macs need a macOS
version supported by the latest Xcode release. On Intel macOS 15, Homebrew also
requires the standalone Command Line Tools directory even when full Xcode is
installed; do not remove `/Library/Developer/CommandLineTools`. If it is
missing, bootstrap opens the [Command Line Tools for Xcode 26.3 download](https://download.developer.apple.com/Developer_Tools/Command_Line_Tools_for_Xcode_26.3/Command_Line_Tools_for_Xcode_26.3.dmg).
Install the downloaded package, then rerun bootstrap.

Homebrew no longer provides Intel bottles for `xcodes`, which would otherwise
make it build from source before Xcode exists. On Intel, bootstrap therefore
downloads Xcodes 2.1.0 from its official GitHub release, verifies its pinned
SHA-256 checksum, and installs the verified universal executable into
Homebrew's `bin` directory. Download `Xcode_26.3_Universal.xip` from Apple
Developer Downloads while authenticated. If `XCODE_XIP_PATH` is not set,
bootstrap opens the official Apple download page in the default browser. Once
the download completes, bootstrap automatically uses
`~/Downloads/Xcode_26.3_Universal.xip`. Rerun it normally:

```bash
./bootstrap.sh
```

Set `XCODE_XIP_PATH` only when the archive is elsewhere.

Bootstrap gives that exact archive to Xcodes and verifies that the installed
app contains an Intel executable before selecting it. Apple Silicon continues
to install Xcodes through Homebrew and download the latest Xcode release.

Homebrew classifies Intel macOS as Tier 3: it does not provide new Intel
bottles, so some packages may build from source and can fail. Homebrew's
current installer no longer bootstraps new Intel installations; for Intel only,
this script uses the immutable upstream installer revision immediately before
that change to install the current Homebrew checkout. Apple Silicon continues
to use Homebrew's current installer.

To preview Ansible changes after bootstrap:

```bash
ansible-playbook -i localhost, playbook.yml --check
```

## Safe reruns

It is safe to rerun `./bootstrap.sh`. The setup converges on the declared tool
list: it installs missing packages but does not upgrade already installed
formulae or casks. Homebrew metadata may be refreshed on each run.

Existing content in `~/.bashrc`, `~/.bash_profile`, and Vim configuration is
preserved. The playbook only maintains its own clearly marked Bash-it,
completion, and Vim tooling blocks. Changes outside those markers remain
untouched; edits inside a managed block are restored to the repository-defined
configuration on the next run. Bash-it and Vim plugin checkouts are not updated
or reset during reruns.

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
- SSH keys, Git user name/email, or shell history
- Existing dotfile content; the only managed shell changes are the clearly
  marked Bash-it, completion, and Vim tooling blocks
- Private Homebrew taps or corporate packages

After provisioning, authenticate each tool through the approved identity and
secrets workflow for the environment you are joining.

## Maintenance

Add only broadly useful tools to `group_vars/all.yml`. Keep
tool installation declarative through the `community.general` Homebrew modules;
do not add a machine-specific package dump.
