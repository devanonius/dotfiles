# shellcheck shell=bash
# Stage 65: machine-specific Hyprland settings that the shared config cannot
# know. Files go in ~/.config/hypr/local/ (loaded by hyprland.lua when they
# exist). Each is written once and then belongs to the user: the installer
# never overwrites it. Laptop/desktop variants of shared files are links
# made by stage 50; monitors are set up on first login by dot-monitors.

LOCAL_HYPR="$HOME/.config/hypr/local"

# NVIDIA: hardware video decoding through VA-API (libva-nvidia-driver) and
# the NVIDIA GLX library. On a hybrid laptop (an Intel or AMD iGPU next to
# the NVIDIA one) Hyprland should run on the iGPU, so only the decoder
# setting is skipped and the file says how to pick the GPU.
nvidia_env() {
  (( ${HAS_NVIDIA:-0} )) || return 0
  local file="$LOCAL_HYPR/env.lua" hybrid=0
  (( HAS_INTEL_GPU || HAS_AMD_GPU )) && hybrid=1
  if [[ -f $file ]]; then
    grep -q 'nvidia' "$file" && { info "nvidia: $(pretty "$file") exists"; return 0; }
    warn "nvidia: $(pretty "$file") exists without NVIDIA settings; leaving it (see docs/SPEC.md, Hardware profiles)"
    return 0
  fi
  changed "write $(pretty "$file") (NVIDIA$( ((hybrid)) && echo ", hybrid graphics"))"
  (( DRY_RUN )) && return 0
  mkdir -p "$LOCAL_HYPR"
  if (( hybrid )); then
    cat > "$file" <<'LUA'
-- Written once by the dotfiles installer for hybrid graphics (an Intel or
-- AMD iGPU plus NVIDIA). Yours to edit; the installer never overwrites it.
--
-- Hyprland runs on the iGPU here and the NVIDIA GPU is used on demand
-- (prime-run <app>). To pin the GPU order, list the cards from
-- `ls -l /dev/dri/by-path`, then e.g.:
--   hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
-- (first card = the one Hyprland renders on).
hl.env("NVD_BACKEND", "direct")
LUA
    warn "hybrid graphics: review $(pretty "$file") (which GPU Hyprland runs on)"
  else
    cat > "$file" <<'LUA'
-- Written once by the dotfiles installer for an NVIDIA GPU. Yours to edit;
-- the installer never overwrites it. (Hyprland wiki: NVIDIA page.)
hl.env("LIBVA_DRIVER_NAME", "nvidia")      -- video decoding via libva-nvidia-driver
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
LUA
  fi
}

# Kernel mode setting is required for Wayland and is on by default since
# driver 560; only report it, because changing it needs a reboot.
nvidia_modeset() {
  (( ${HAS_NVIDIA:-0} )) || return 0
  local param=/sys/module/nvidia_drm/parameters/modeset
  if [[ ! -r $param ]]; then
    info "nvidia: driver not loaded yet (reboot after the first install)"
  elif [[ $(<"$param") == Y ]]; then
    info "nvidia: kernel mode setting on"
  else
    warn "nvidia: nvidia_drm.modeset is off; add nvidia_drm.modeset=1 to the kernel command line"
  fi
}

stage_main() {
  if [[ $(config_get 'if has("hardware") then .hardware else true end') != true ]]; then
    info "skipped (\"hardware\": false)"
    return 0
  fi
  nvidia_env
  nvidia_modeset
  info "laptop: $( (( ${IS_LAPTOP:-0} )) && echo "yes (laptop idle timeouts and bar)" || echo "no (desktop idle timeouts, no battery in the bar)")"
}
