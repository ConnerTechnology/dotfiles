#!/usr/bin/env bash

# GPG key registry for apt repositories managed by ctdev components.
# Each entry: "component|key_url|keyring_path|method"
#   method: "raw" = download as-is, "dearmor" = pipe through gpg --dearmor

APT_KEY_REGISTRY=(
    "docker|https://download.docker.com/linux/ubuntu/gpg|/etc/apt/keyrings/docker.asc|raw"
    "gh|https://cli.github.com/packages/githubcli-archive-keyring.gpg|/usr/share/keyrings/githubcli-archive-keyring.gpg|dearmor"
    "1password|https://downloads.1password.com/linux/keys/1password.asc|/usr/share/keyrings/1password-archive-keyring.gpg|dearmor"
    "1password|https://downloads.1password.com/linux/keys/1password.asc|/usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg|dearmor"
    "terraform|https://apt.releases.hashicorp.com/gpg|/usr/share/keyrings/hashicorp-archive-keyring.gpg|dearmor"
    "vscode|https://packages.microsoft.com/keys/microsoft.asc|/etc/apt/trusted.gpg.d/packages.microsoft.gpg|dearmor"
    "dbeaver|https://dbeaver.io/debs/dbeaver.gpg.key|/etc/apt/trusted.gpg.d/dbeaver.gpg|dearmor"
    "tailscale|https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg|/usr/share/keyrings/tailscale-archive-keyring.gpg|raw"
)

# Refresh a single apt GPG key.
# Args: key_url keyring_path method
refresh_apt_key() {
    local key_url="$1"
    local keyring_path="$2"
    local method="$3"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would refresh key: $key_url -> $keyring_path"
        return 0
    fi

    local keyring_dir
    keyring_dir="$(dirname "$keyring_path")"
    maybe_sudo mkdir -p "$keyring_dir"

    if [[ "$method" == "raw" ]]; then
        maybe_sudo curl -fsSL "$key_url" -o "$keyring_path"
        maybe_sudo chmod a+r "$keyring_path"
    else
        curl -fsSL "$key_url" | maybe_sudo gpg --batch --yes --dearmor -o "$keyring_path"
        maybe_sudo chmod a+r "$keyring_path"
    fi
}

# Refresh GPG keys for installed components.
# Args: [component...] — if empty, refreshes all installed components
refresh_keys() {
    local filter=("$@")
    local refreshed=0
    local failed=0
    local skipped=0
    local seen_components=()

    for entry in "${APT_KEY_REGISTRY[@]}"; do
        IFS='|' read -r component key_url keyring_path method <<< "$entry"

        # Apply component filter if provided
        if [[ ${#filter[@]} -gt 0 ]]; then
            local matched=false
            for f in "${filter[@]}"; do
                if [[ "$f" == "$component" ]]; then
                    matched=true
                    break
                fi
            done
            if [[ "$matched" == "false" ]]; then
                continue
            fi
        fi

        # Skip if component not installed
        if ! is_component_installed "$component"; then
            # Only log skip once per component
            local already_seen=false
            for seen in "${seen_components[@]}"; do
                if [[ "$seen" == "$component" ]]; then
                    already_seen=true
                    break
                fi
            done
            if [[ "$already_seen" == "false" ]]; then
                log_info "Skipping $component (not installed)"
                seen_components+=("$component")
            fi
            ((skipped++))
            continue
        fi

        log_info "Refreshing key for $component: $keyring_path"
        if refresh_apt_key "$key_url" "$keyring_path" "$method"; then
            log_success "Refreshed $keyring_path"
            ((refreshed++))
        else
            log_error "Failed to refresh key for $component: $keyring_path"
            ((failed++))
        fi
    done

    echo
    if [[ $refreshed -gt 0 ]]; then
        log_success "Refreshed $refreshed key(s)"
    fi
    if [[ $failed -gt 0 ]]; then
        log_error "Failed to refresh $failed key(s)"
        return 1
    fi
    if [[ $refreshed -eq 0 && $failed -eq 0 ]]; then
        log_info "No installed components with apt keys to refresh"
    fi

    return 0
}
