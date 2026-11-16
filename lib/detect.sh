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
