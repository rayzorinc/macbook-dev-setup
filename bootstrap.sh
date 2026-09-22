#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap script supports macOS only." >&2
  exit 1
fi

case "$(uname -m)" in
  arm64)
    homebrew_prefix="/opt/homebrew"
    homebrew_installer_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    ;;
  x86_64)
    homebrew_prefix="/usr/local"
    # Homebrew 7 still runs on Intel macOS as a Tier 3 configuration, but the
    # current installer no longer bootstraps a new Intel installation. This is
    # the immutable upstream revision immediately before that restriction; it
    # installs the current Homebrew checkout at the Intel default prefix.
    homebrew_installer_url="https://raw.githubusercontent.com/Homebrew/install/7a133dcc74051ee4efc79467ed215dfedf45aea2/install.sh"
    ;;
  *)
    echo "Unsupported macOS architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

homebrew_bin="${homebrew_prefix}/bin/brew"
xcode_install_directory="/Applications"
xcodes_version="2.1.0"
xcodes_release_url="https://github.com/XcodesOrg/xcodes/releases/download/${xcodes_version}/xcodes.zip"
xcodes_release_sha256="f1519afe934a513e85dd9b32fc872394becbbb6a41db15d9ac3926a09a891888"
xcode_intel_download_url="https://developer.apple.com/services-account/download?path=/Developer_Tools/Xcode_26.3/Xcode_26.3_Universal.xip"
command_line_tools_download_url="https://download.developer.apple.com/Developer_Tools/Command_Line_Tools_for_Xcode_26.3/Command_Line_Tools_for_Xcode_26.3.dmg"

case "$(uname -m)" in
  arm64)
    xcode_install_request="--latest"
    xcode_app_pattern="Xcode*.app"
    xcode_description="the latest release"
    xcode_update_on_rerun=true
    ;;
  x86_64)
    xcode_install_request="26.3"
    xcode_app_pattern="Xcode-26.3*.app"
    xcode_description="Xcode 26.3"
    xcode_update_on_rerun=false
    ;;
esac

install_available_command_line_tools_update() {
  local available_updates
  local command_line_tools_label

  if ! available_updates="$(softwareupdate --list 2>&1)"; then
    echo "Unable to check for Command Line Tools updates; continuing with the installed tools." >&2
    return 0
  fi

  command_line_tools_label="$(printf '%s\n' "${available_updates}" | sed -nE 's/^[[:space:]]*\* Label: (Command Line Tools for Xcode.*)$/\1/p' | tail -n 1)"
  if [[ -z "${command_line_tools_label}" ]]; then
    echo "No newer Command Line Tools package is available through Software Update."
    echo "For a specific Xcode release, install its Command Line Tools package from Apple Developer Downloads."
    return 0
  fi

  echo "Installing available Command Line Tools update: ${command_line_tools_label}"
  sudo softwareupdate --install "${command_line_tools_label}"
}

version_is_newer() {
  awk -v candidate="$1" -v current="$2" '
    BEGIN {
      split(candidate, candidate_parts, ".")
      split(current, current_parts, ".")
      for (index = 1; index <= 4; index++) {
        candidate_part = candidate_parts[index] + 0
        current_part = current_parts[index] + 0
        if (candidate_part > current_part) exit 0
        if (candidate_part < current_part) exit 1
      }
      exit 1
    }
  '
}

latest_xcode_app() {
  local candidate_app
  local candidate_version
  local latest_app=""
  local latest_version=""

  while IFS= read -r -d '' candidate_app; do
    candidate_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${candidate_app}/Contents/version.plist" 2>/dev/null || true)"
    if [[ -n "${candidate_version}" ]] && { [[ -z "${latest_version}" ]] || version_is_newer "${candidate_version}" "${latest_version}"; }; then
      latest_app="${candidate_app}"
      latest_version="${candidate_version}"
    fi
  done < <(find "${xcode_install_directory}" -maxdepth 1 -type d -name "Xcode*.app" -print0)

  printf '%s\n' "${latest_app}"
}

install_xcodes() {
  local xcodes_archive
  local xcodes_download_sha256
  local xcodes_temp_directory

  if command -v xcodes >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$(uname -m)" == "arm64" ]]; then
    brew install xcodesorg/made/xcodes
    return 0
  fi

  echo "Installing the official prebuilt Xcodes ${xcodes_version} release for Intel macOS."
  xcodes_temp_directory="$(mktemp -d -t xcodes-install)"
  xcodes_archive="${xcodes_temp_directory}/xcodes.zip"
  curl --fail --location --show-error --silent --output "${xcodes_archive}" "${xcodes_release_url}"
  xcodes_download_sha256="$(shasum -a 256 "${xcodes_archive}" | awk '{print $1}')"
  if [[ "${xcodes_download_sha256}" != "${xcodes_release_sha256}" ]]; then
    echo "Downloaded Xcodes archive failed its SHA-256 integrity check." >&2
    exit 1
  fi

  unzip -p "${xcodes_archive}" xcodes > "${xcodes_temp_directory}/xcodes"
  install -m 0755 "${xcodes_temp_directory}/xcodes" "${homebrew_prefix}/bin/xcodes"
  rm -rf "${xcodes_temp_directory}"
}

install_requested_xcode() {
  local xcode_xip_path="${XCODE_XIP_PATH:-}"

  if [[ "$(uname -m)" == "x86_64" ]]; then
    if [[ -z "${xcode_xip_path}" && -f "${HOME}/Downloads/Xcode_26.3_Universal.xip" ]]; then
      xcode_xip_path="${HOME}/Downloads/Xcode_26.3_Universal.xip"
    fi

    if [[ -z "${xcode_xip_path}" ]]; then
      echo "Intel macOS requires the Universal Xcode archive." >&2
      echo "Opening Apple's sign-in page for Xcode_26.3_Universal.xip." >&2
      open "${xcode_intel_download_url}"
      echo "After the browser download completes, rerun ./bootstrap.sh." >&2
      echo "Or set XCODE_XIP_PATH if you downloaded it somewhere else." >&2
      exit 1
    fi
    if [[ ! -f "${xcode_xip_path}" ]]; then
      echo "XCODE_XIP_PATH does not point to a file: ${xcode_xip_path}" >&2
      exit 1
    fi

    # Xcodes' remote sources can choose an Apple Silicon-only archive for this
    # release on Intel. Supplying Apple's Universal archive bypasses that
    # selection and leaves Xcodes to perform the normal verification/install.
    xcodes install "${xcode_install_request}" --path "${xcode_xip_path}"
  else
    xcodes install "${xcode_install_request}"
  fi
}

verify_xcode_architecture() {
  local xcode_architectures

  if [[ "$(uname -m)" != "x86_64" ]]; then
    return 0
  fi

  xcode_architectures="$(lipo -archs "$1/Contents/Developer/usr/bin/xcodebuild")"
  if [[ " ${xcode_architectures} " != *" x86_64 "* ]]; then
    echo "${1} does not contain an Intel x86_64 Xcode build." >&2
    echo "Remove that incompatible Xcode app, then rerun bootstrap to download the Universal build." >&2
    exit 1
  fi
}

install_xcode() {
  local xcode_app

  if [[ "${xcode_update_on_rerun}" == true ]]; then
    echo "Installing Xcodes and ${xcode_description}."
    install_xcodes
    # Xcodes prompts for an Apple ID and any required two-factor code. It stores
    # the authenticated session in the user's Keychain rather than this repo.
    install_requested_xcode
    xcode_app="$(latest_xcode_app)"
  else
    xcode_app="$(find "${xcode_install_directory}" -maxdepth 1 -type d -name "${xcode_app_pattern}" -print -quit)"
  fi

  if [[ -z "${xcode_app}" ]]; then
    echo "Installing Xcodes and ${xcode_description}."
    install_xcodes
    # Xcodes prompts for an Apple ID and any required two-factor code. It stores
    # the authenticated session in the user's Keychain rather than this repo.
    install_requested_xcode
    xcode_app="$(find "${xcode_install_directory}" -maxdepth 1 -type d -name "${xcode_app_pattern}" -print -quit)"
  fi

  if [[ -z "${xcode_app}" ]]; then
    echo "${xcode_description} was not found in ${xcode_install_directory} after installation." >&2
    exit 1
  fi

  verify_xcode_architecture "${xcode_app}"
  echo "Selecting ${xcode_description}: ${xcode_app}"
  sudo xcode-select --switch "${xcode_app}/Contents/Developer"
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
}

load_homebrew() {
  if [[ -x "${homebrew_bin}" ]]; then
    # Homebrew is not necessarily on PATH after a fresh installation. Its
    # default prefix is /usr/local on Intel and /opt/homebrew on Apple Silicon.
    eval "$("${homebrew_bin}" shellenv)"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    homebrew_bin="$(command -v brew)"
    eval "$("${homebrew_bin}" shellenv)"
    return 0
  fi

  return 1
}

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Apple's Command Line Tools. Complete the macOS prompt, then rerun this script."
  xcode-select --install
  exit 0
fi

if [[ ! -x "/Library/Developer/CommandLineTools/usr/bin/clang" ]]; then
  echo "Homebrew requires Apple's standalone Command Line Tools on this macOS configuration." >&2
  echo "Opening the Command Line Tools for Xcode 26.3 download page." >&2
  open "${command_line_tools_download_url}"
  echo "Install the downloaded package, then rerun this script." >&2
  exit 0
fi

install_available_command_line_tools_update

if ! load_homebrew; then
  echo "Installing Homebrew."
  if [[ "$(uname -m)" == "x86_64" ]]; then
    echo "Intel macOS is a Homebrew Tier 3 configuration; some formulae may build from source."
  fi

  homebrew_installer_path="$(mktemp -t homebrew-install)"
  trap 'rm -f "${homebrew_installer_path}"' EXIT
  curl --fail --location --show-error --silent --output "${homebrew_installer_path}" "${homebrew_installer_url}"
  /bin/bash "${homebrew_installer_path}"
  rm -f "${homebrew_installer_path}"
  trap - EXIT
fi

if ! load_homebrew; then
  echo "Homebrew was installed but could not be found at ${homebrew_bin}." >&2
  exit 1
fi

brew update
install_xcode
brew install ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i localhost, playbook.yml
