# shellcheck shell=bash
# Hardware and system detection. Sourced by stage 10-detect.
# Each detector reads /sys or package state only, so it works before any
# desktop packages are installed (no lspci, no Hyprland session needed).
# DOTFILES_SYSROOT exists only so tests can point detection at a fake /sys.
: "${DOTFILES_SYSROOT:=}"

# Any battery means a laptop.
detect_laptop() {
  compgen -G "$DOTFILES_SYSROOT/sys/class/power_supply/BAT*" >/dev/null
}

# Print the vendor ids of all display controllers (PCI class 0x03xxxx).
_display_vendors() {
  local dev
  for dev in "$DOTFILES_SYSROOT"/sys/bus/pci/devices/*; do
    [[ -r $dev/class && -r $dev/vendor ]] || continue
    [[ $(<"$dev/class") == 0x03* ]] && printf '%s\n' "$(<"$dev/vendor")"
  done
  return 0
}

# PCI vendor ids: NVIDIA 0x10de, Intel 0x8086, AMD 0x1002.
detect_nvidia()    { _display_vendors | grep -qx '0x10de'; }
detect_intel_gpu() { _display_vendors | grep -qx '0x8086'; }
detect_amd_gpu()   { _display_vendors | grep -qx '0x1002'; }

# --- NVIDIA driver choice -------------------------------------------------
# Arch (driver 590+, Dec 2025): the repo packages (nvidia-open*) support
# Turing and newer only. Maxwell, Pascal and Volta need nvidia-580xx-dkms
# from the AUR; Kepler and older have no maintained driver (nouveau).
# The generation is read from the PCI device id: Turing starts at 0x1e00,
# first-generation Maxwell at 0x1340.

# Print the device ids of NVIDIA display controllers.
nvidia_device_ids() {
  local dev
  for dev in "$DOTFILES_SYSROOT"/sys/bus/pci/devices/*; do
    [[ -r $dev/class && -r $dev/vendor && -r $dev/device ]] || continue
    [[ $(<"$dev/class") == 0x03* && $(<"$dev/vendor") == 0x10de ]] && printf '%s\n' "$(<"$dev/device")"
  done
  return 0
}

# Print open, 580xx or legacy for the newest NVIDIA GPU (none if no GPU).
nvidia_generation() {
  local id best=0
  while read -r id; do
    (( id > best )) && best=$((id))
  done < <(nvidia_device_ids)
  if   (( best == 0 ));      then echo none
  elif (( best >= 0x1e00 )); then echo open
  elif (( best >= 0x1340 )); then echo 580xx
  else                            echo legacy
  fi
}

# Kernels installed through pacman (linux, linux-lts, linux-zen, ...).
installed_kernels() {
  has_cmd pacman || return 0
  pacman -Qq linux linux-lts linux-zen linux-hardened linux-rt linux-rt-lts 2>/dev/null || true
}

multilib_enabled() { grep -q '^\[multilib\]' "$DOTFILES_SYSROOT/etc/pacman.conf" 2>/dev/null; }

# A driver already on the system (e.g. chosen in archinstall) always wins:
# switching drivers is a manual decision. Prints its family: open or 580xx.
nvidia_installed_family() {
  has_cmd pacman || return 0
  local pkg
  for pkg in nvidia-open nvidia-open-dkms nvidia-open-lts nvidia nvidia-dkms nvidia-lts; do
    pacman -Qq "$pkg" >/dev/null 2>&1 && { echo open; return 0; }
  done
  for pkg in nvidia-580xx-dkms nvidia-580xx; do
    pacman -Qq "$pkg" >/dev/null 2>&1 && { echo 580xx; return 0; }
  done
  return 0
}

# One line for the installer log: which generation and driver family.
nvidia_summary() {
  local installed gen
  installed=$(nvidia_installed_family)
  gen=$(nvidia_generation)
  case $gen in
    open)   gen="Turing or newer" ;;
    580xx)  gen="Maxwell/Pascal/Volta" ;;
    legacy) gen="Kepler or older: no maintained driver, using nouveau" ;;
  esac
  if [[ -n $installed ]]; then
    echo "$gen; keeping the installed $installed driver"
  else
    echo "$gen"
  fi
}

# nvidia_packages repo|aur [choice]: driver packages for this machine.
# choice: auto (default), open, 580xx or none (install config "nvidia_driver").
nvidia_packages() {
  local source=$1 choice=${2:-auto} family installed kernels=() k
  (( ${HAS_NVIDIA:-0} )) || return 0
  installed=$(nvidia_installed_family)
  case $choice in
    none) return 0 ;;
    open|580xx) family=$choice ;;
    *) family=${installed:-$(nvidia_generation)} ;;
  esac
  mapfile -t kernels < <(installed_kernels)

  case $family in
    open)
      [[ $source == repo ]] || return 0
      if [[ -z $installed ]]; then
        # Prebuilt modules when only the stock or LTS kernel is installed;
        # DKMS (built per kernel, needs headers) for anything else.
        if [[ ${kernels[*]} == linux ]]; then echo nvidia-open
        elif [[ ${kernels[*]} == linux-lts ]]; then echo nvidia-open-lts
        else
          echo nvidia-open-dkms
          for k in "${kernels[@]}"; do echo "$k-headers"; done
        fi
      fi
      echo nvidia-utils
      echo libva-nvidia-driver
      multilib_enabled && echo lib32-nvidia-utils
      (( ${HAS_INTEL_GPU:-0} || ${HAS_AMD_GPU:-0} )) && echo nvidia-prime   # prime-run on hybrid laptops
      ;;
    580xx)
      if [[ $source == repo ]]; then
        for k in "${kernels[@]}"; do echo "$k-headers"; done
        echo libva-nvidia-driver
        (( ${HAS_INTEL_GPU:-0} || ${HAS_AMD_GPU:-0} )) && echo nvidia-prime
      else
        [[ -z $installed ]] && echo nvidia-580xx-dkms
        echo nvidia-580xx-utils
        multilib_enabled && echo lib32-nvidia-580xx-utils
      fi
      ;;
  esac
  return 0
}

# Print intel, amd or unknown from the first CPU's vendor_id.
detect_cpu_vendor() {
  local vendor
  vendor=$(awk -F': *' '/^vendor_id/ {print $2; exit}' "$DOTFILES_SYSROOT/proc/cpuinfo" 2>/dev/null)
  case $vendor in
    GenuineIntel) echo intel ;;
    AuthenticAMD) echo amd ;;
    *)            echo unknown ;;
  esac
}

detect_hyprland() {
  has_cmd pacman && pacman -Qq hyprland >/dev/null 2>&1
}

# Monitor count from a running Hyprland session, 0 when unknown.
detect_monitor_count() {
  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && has_cmd hyprctl; then
    hyprctl monitors 2>/dev/null | grep -c '^Monitor ' || true
  else
    echo 0
  fi
}

detect_all() {
  IS_LAPTOP=0 HAS_NVIDIA=0 HAS_INTEL_GPU=0 HAS_AMD_GPU=0 HAS_HYPRLAND=0
  detect_laptop    && IS_LAPTOP=1
  detect_nvidia    && HAS_NVIDIA=1
  detect_intel_gpu && HAS_INTEL_GPU=1
  detect_amd_gpu   && HAS_AMD_GPU=1
  detect_hyprland  && HAS_HYPRLAND=1
  CPU_VENDOR=$(detect_cpu_vendor)
  MONITOR_COUNT=$(detect_monitor_count)
  export IS_LAPTOP HAS_NVIDIA HAS_INTEL_GPU HAS_AMD_GPU HAS_HYPRLAND CPU_VENDOR MONITOR_COUNT
}

# Print the packages/hardware/<name> lists that match this machine.
hardware_lists() {
  case $CPU_VENDOR in
    intel) echo cpu-intel ;;
    amd)   echo cpu-amd ;;
  esac
  (( HAS_INTEL_GPU )) && echo gpu-intel
  (( HAS_AMD_GPU ))   && echo gpu-amd
  (( HAS_NVIDIA ))    && echo gpu-nvidia
  (( IS_LAPTOP ))     && echo laptop
  return 0
}
