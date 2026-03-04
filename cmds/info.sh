#!/usr/bin/env bash

# ctdev info - Show system information

cmd_info() {
    local version
    version=$(get_version)

    echo
    log_step "System Information"
    echo

    # OS
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        # shellcheck disable=SC2153
        echo "  OS:              $NAME $VERSION"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  OS:              macOS $(sw_vers -productVersion)"
    else
        echo "  OS:              $(uname -s)"
    fi

    # Architecture
    echo "  Architecture:    $(uname -m)"

    # Package manager
    local pkg_manager
    pkg_manager=$(get_package_manager)
    echo "  Package Manager: $pkg_manager"

    # Shell
    echo "  Shell:           ${SHELL:-unknown}"

    # Dotfiles location
    echo "  Dotfiles:        $DOTFILES_ROOT"

    # ctdev version
    echo "  ctdev:           $version"

    echo
    log_step "Hardware"
    echo

    # CPU with thread count
    local cpu_info cpu_threads
    if [[ "$OSTYPE" == "darwin"* ]]; then
        cpu_info=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
        cpu_threads=$(sysctl -n hw.ncpu 2>/dev/null)
    elif [[ -f /proc/cpuinfo ]]; then
        cpu_info=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
        cpu_threads=$(grep -c "^processor" /proc/cpuinfo)
    else
        cpu_info="unknown"
        cpu_threads=$(nproc 2>/dev/null)
    fi
    if [[ -n "$cpu_threads" ]]; then
        echo "  CPU:             $cpu_info ($cpu_threads threads)"
    else
        echo "  CPU:             $cpu_info"
    fi

    # Memory (snap to nearest standard RAM size)
    local mem_display
    snap_to_standard_ram() {
        local gb=$1
        # Standard RAM sizes
        local sizes=(4 8 16 32 64 128 256 512 1024)
        for size in "${sizes[@]}"; do
            # If within 10% of a standard size, snap to it
            if (( gb >= size * 90 / 100 && gb <= size * 110 / 100 )); then
                echo "$size"
                return
            fi
        done
        echo "$gb"
    }
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
        if [[ -n "$mem_bytes" ]]; then
            mem_gb=$(( mem_bytes / 1073741824 ))
            mem_gb=$(snap_to_standard_ram "$mem_gb")
            mem_display="${mem_gb} GB"
        else
            mem_display="unknown"
        fi
    elif [[ -f /proc/meminfo ]]; then
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        mem_gb=$(( mem_kb / 1048576 ))
        mem_gb=$(snap_to_standard_ram "$mem_gb")
        mem_display="${mem_gb} GB"
    else
        mem_display="unknown"
    fi
    echo "  Memory:          $mem_display"

    # GPU (if available)
    local gpu_info=""
    local gpu_vram=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        gpu_info=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Chipset Model" | head -1 | cut -d: -f2 | sed 's/^ //' || true)
    elif command -v nvidia-smi >/dev/null 2>&1; then
        # NVIDIA GPU with nvidia-smi available
        gpu_info=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)
        gpu_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1 | sed 's/ MiB//' || true)
        if [[ -n "$gpu_vram" ]]; then
            # Convert MiB to GB (round)
            gpu_vram_gb=$(( (gpu_vram + 512) / 1024 ))
            gpu_info="$gpu_info (${gpu_vram_gb} GB VRAM)"
        fi
    elif command -v lspci >/dev/null 2>&1; then
        gpu_info=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | head -1 | sed 's/.*: //' || true)
    fi
    if [[ -n "$gpu_info" ]]; then
        echo "  GPU:             $gpu_info"
    fi

    # Disk (root filesystem) - show used/total and percentage
    local disk_used disk_total disk_percent
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS APFS: df reports misleading numbers, use diskutil instead
        local container_total container_free
        container_total=$(diskutil info / 2>/dev/null | grep "Container Total Space" | awk -F'[()]' '{print $2}' | awk '{print $1}' || true)
        container_free=$(diskutil info / 2>/dev/null | grep "Container Free Space" | awk -F'[()]' '{print $2}' | awk '{print $1}' || true)
        if [[ -n "$container_total" && -n "$container_free" ]]; then
            local used_bytes=$(( container_total - container_free ))
            # Convert to human readable
            disk_total=$(echo "$container_total" | awk '{printf "%.0f GB", $1/1000000000}')
            disk_used=$(echo "$used_bytes" | awk '{printf "%.0f GB", $1/1000000000}')
            disk_percent=$(awk "BEGIN {printf \"%.0f%%\", ($used_bytes/$container_total)*100}")
            echo "  Disk (/):        $disk_used / $disk_total ($disk_percent used)"
        fi
    elif command -v df >/dev/null 2>&1; then
        read -r disk_total disk_used disk_percent <<< "$(df -h / 2>/dev/null | awk 'NR==2 {print $2, $3, $5}')"
        # Format: 1.8T -> 1.8 TB, 500G -> 500 GB
        disk_total=$(echo "$disk_total" | sed 's/T$/ TB/; s/G$/ GB/; s/M$/ MB/')
        disk_used=$(echo "$disk_used" | sed 's/T$/ TB/; s/G$/ GB/; s/M$/ MB/')
        echo "  Disk (/):        $disk_used / $disk_total ($disk_percent used)"
    fi

    # Recommended Chrome Web Apps (Linux only, Chrome installed)
    if [[ "$OSTYPE" != "darwin"* ]] && command -v google-chrome >/dev/null 2>&1; then
        echo
        log_step "Recommended Chrome Web Apps"
        echo
        echo "  Install as web apps via chrome://apps/ or the browser menu"
        echo "  (three dots → Cast, save, and share → Install page as app)"
        echo
        echo "  - TradingView        https://www.tradingview.com"
        echo "  - ChatGPT            https://chatgpt.com"
        echo
    fi

    echo
}
