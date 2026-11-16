# shellcheck shell=bash
# Stage 10: detect hardware and what is already installed.

stage_main() {
  # shellcheck source=lib/detect.sh
  source "$DOTFILES_DIR/lib/detect.sh"
  detect_all
  local gpus=()
  (( HAS_INTEL_GPU )) && gpus+=(intel)
  (( HAS_AMD_GPU ))   && gpus+=(amd)
  (( HAS_NVIDIA ))    && gpus+=(nvidia)
  info "cpu:            $CPU_VENDOR"
  info "gpu:            ${gpus[*]:-none found}$( (( ${#gpus[@]} > 1 )) && echo '  (more than one: possibly hybrid graphics)')"
  info "laptop:         $( (( IS_LAPTOP )) && echo yes || echo no)"
  info "hyprland:       $( (( HAS_HYPRLAND )) && echo 'already installed' || echo 'not installed')"
  info "monitors:       $( (( MONITOR_COUNT )) && echo "$MONITOR_COUNT" || echo 'unknown (no Hyprland session)')"
}
