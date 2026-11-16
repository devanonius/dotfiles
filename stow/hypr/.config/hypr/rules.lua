-- Window rules. Find a window's class with: hyprctl clients
hl.window_rule({
  name = "float-dialogs",
  match = { class = "^(xdg-desktop-portal-gtk|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager)$" },
  float = true,
})

hl.window_rule({
  name = "float-file-pickers",
  match = { title = "^(Open File|Save File|Open Folder|Save As)(.*)$" },
  float = true,
})
