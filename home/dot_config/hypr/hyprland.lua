-- Native Hyprland Lua configuration (0.56+).
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = "auto" })
hl.monitor({
    output = "desc:Acer Technologies XV272U W2", mode = "2560x1440@144",
    position = "-2560x0", scale = 1,
})
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("TERMINAL", "kitty")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("XCURSOR_SIZE", "24")
hl.env("SSH_AUTH_SOCK", os.getenv("HOME") .. "/.1password/agent.sock")
hl.config({
    general = {
        gaps_in = 4, gaps_out = 8, border_size = 2, layout = "dwindle",
        col = { active_border = "rgb(7cab3d)", inactive_border = "rgb(3c502b)" },
        resize_on_border = true,
    },
    decoration = {
        rounding = 12,
        shadow = { enabled = true, range = 8, render_power = 3, color = 0x66000000 },
        blur = { enabled = true, size = 8, passes = 3, popups = true, input_methods = true },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    input = {
        kb_layout = "us", kb_options = "korean:ralt_hangul",
        follow_mouse = 1, accel_profile = "flat",
    },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
})
-- Canopy owns its motion; keep layer mapping stationary even before animations settle.
hl.layer_rule({ match = { namespace = "canopy-.*" }, no_anim = true, animation = "fade" })
hl.layer_rule({ match = { namespace = "canopy-launcher" }, blur = true, ignore_alpha = 0.3 })
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE SSH_AUTH_SOCK TERMINAL QT_QPA_PLATFORMTHEME QT_IM_MODULE XMODIFIERS")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("env QML_DISABLE_DISK_CACHE=1 quickshell --no-duplicate --config canopy")
    hl.exec_cmd("1password --silent")
end)

hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("kitty yazi"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("helium-browser"))
hl.bind("SUPER + Space", hl.dsp.exec_cmd("quickshell --config canopy ipc call launcher toggle"))
hl.bind("SUPER + CTRL + Space", hl.dsp.exec_cmd("quickshell --config canopy ipc call launcher files"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("quickshell --config canopy ipc call panel toggle"))
hl.bind("SUPER + SHIFT + O", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + SHIFT + Return", hl.dsp.layout("movetoroot"))
hl.bind("SUPER + X", hl.dsp.layout("swapsplit"))
hl.bind("SUPER + Y", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + M", hl.dsp.window.move({ workspace = "special:parked" }))
hl.bind("SUPER + SHIFT + M", hl.dsp.workspace.toggle_special("parked"))
hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd("loginctl lock-session"))

for key, direction in pairs({ H = "left", J = "down", K = "up", L = "right" }) do
    hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = direction }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end
for key, direction in pairs({ left = "left", down = "down", up = "up", right = "right" }) do
    hl.bind("SUPER + " .. key, hl.dsp.window.move({ into_or_create_group = direction }))
end
hl.bind("SUPER + semicolon", hl.dsp.window.move({ out_of_group = true }))
hl.bind("SUPER + bracketleft", hl.dsp.group.prev())
hl.bind("SUPER + bracketright", hl.dsp.group.next())
hl.bind("SUPER + SHIFT + bracketleft", hl.dsp.window.cycle_next({ next = false }))
hl.bind("SUPER + SHIFT + bracketright", hl.dsp.window.cycle_next())
hl.bind("SUPER + equal", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + minus", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
for i = 1, 8 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("Print", hl.dsp.exec_cmd("~/.local/bin/screenshot"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("~/.local/bin/screenshot region"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.local/bin/screen-brightness change 5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.local/bin/screen-brightness change -5"), { locked = true, repeating = true })
