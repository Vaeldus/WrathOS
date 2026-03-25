#!/usr/bin/env python3

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib
import subprocess
import threading
import os
import sys

BUNDLES = [
    {
        "id": "gpu",
        "packages": ["mesa-vulkan-drivers", "libvulkan1", "vulkan-tools"],
        "flatpak": [],
        "name": "GPU Drivers",
        "desc": "Mesa Vulkan drivers for AMD and Intel GPUs",
        "recommended": True,
        "default": True,
    },
    {
        "id": "steam",
        "packages": ["flatpak", "libvulkan1"],
        "flatpak": [("com.valvesoftware.Steam", "Steam")],
        "name": "Steam",
        "desc": "Steam via Flatpak · Vulkan libraries",
        "recommended": True,
        "default": True,
    },
    {
        "id": "perf",
        "packages": ["gamemode", "mangohud"],
        "flatpak": [],
        "name": "Performance Tools",
        "desc": "GameMode · MangoHud",
        "recommended": True,
        "default": True,
    },
    {
        "id": "codecs",
        "packages": ["ffmpeg", "gstreamer1.0-plugins-good", "gstreamer1.0-plugins-bad", "gstreamer1.0-plugins-ugly", "gstreamer1.0-libav", "flatpak"],
        "flatpak": [("org.videolan.VLC", "VLC")],
        "name": "Media Codecs",
        "desc": "FFmpeg · GStreamer · VLC",
        "recommended": True,
        "default": True,
    },
    {
        "id": "launchers",
        "packages": ["lutris", "flatpak"],
        "flatpak": [("com.heroicgameslauncher.hgl", "Heroic"), ("com.usebottles.bottles", "Bottles")],
        "name": "Launchers",
        "desc": "Lutris · Heroic · Bottles",
        "recommended": False,
        "default": False,
    },
    {
        "id": "emulation",
        "packages": ["dolphin-emu", "flatpak"],
        "flatpak": [("org.libretro.RetroArch", "RetroArch")],
        "name": "Emulation",
        "desc": "Dolphin · RetroArch",
        "recommended": False,
        "default": False,
    },
]

INSTALLED_FILE = os.path.expanduser("~/.wrathos-bundles-installed")

def get_installed_bundles():
    if not os.path.exists(INSTALLED_FILE):
        return set()
    with open(INSTALLED_FILE) as f:
        return set(line.strip() for line in f if line.strip())

def mark_installed(bundle_ids):
    installed = get_installed_bundles()
    installed.update(bundle_ids)
    with open(INSTALLED_FILE, 'w') as f:
        f.write('\n'.join(sorted(installed)) + '\n')

AUTOSTART_FILE = os.path.expanduser(
    "~/.config/autostart/wrathos-configurator.desktop"
)

AUTOSTART_CONTENT = """[Desktop Entry]
Type=Application
Name=WrathOS Setup
Exec=wrathos-configurator
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-KDE-autostart-phase=2
"""

CSS = b"""
window { background-color: #0a0a0a; }
.wrathos-title { color: #dddddd; font-size: 20px; font-weight: bold; }
.wrathos-subtitle { color: #883333; font-size: 11px; letter-spacing: 2px; }
.wrathos-hint { color: #666666; font-size: 11px; }
.bundle-card {
    background-color: #1a1a1a;
    border: 1px solid #2a0000;
    border-radius: 6px;
    padding: 12px;
}
.bundle-card-selected {
    background-color: #1a0808;
    border: 1.5px solid #aa2222;
    border-radius: 6px;
    padding: 12px;
}
.bundle-name { color: #dddddd; font-size: 13px; font-weight: bold; }
.bundle-desc { color: #666666; font-size: 11px; }
.bundle-desc-selected { color: #cc2222; font-size: 11px; }
.bundle-tag { color: #666666; font-size: 10px; }
.bundle-tag-recommended { color: #883333; font-size: 10px; }
.install-btn {
    background-color: #8b0000;
    color: #dddddd;
    border: 1px solid #cc2222;
    border-radius: 6px;
    font-weight: bold;
    font-size: 13px;
    padding: 10px;
}
.install-btn:hover { background-color: #aa0000; }
.install-btn:disabled { background-color: #3a0000; color: #666666; }
.skip-btn { color: #666666; font-size: 11px; }
.progress-label { color: #dddddd; font-size: 13px; }
.done-label { color: #44aa44; font-size: 15px; font-weight: bold; }
.autostart-label { color: #dddddd; font-size: 13px; }
.autostart-hint { color: #666666; font-size: 11px; }
.yes-btn {
    background-color: #1a3a1a;
    color: #88cc88;
    border: 1px solid #2a6a2a;
    border-radius: 6px;
    font-size: 13px;
    padding: 8px;
}
.no-btn {
    background-color: #1a1a1a;
    color: #666666;
    border: 1px solid #333333;
    border-radius: 6px;
    font-size: 13px;
    padding: 8px;
}
"""

class WrathOSConfigurator(Adw.Application):
    def __init__(self):
        super().__init__(application_id="os.wrathos.configurator")
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        self.win = Gtk.ApplicationWindow(application=app)
        self.win.set_title("WrathOS Setup")
        self.win.set_default_size(580, 680)
        self.win.set_resizable(False)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            self.win.get_display(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.checks = {}
        self.build_main_view()
        self.win.present()

    def build_main_view(self):
        self.main_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=0
        )
        self.main_box.set_margin_top(32)
        self.main_box.set_margin_bottom(24)
        self.main_box.set_margin_start(40)
        self.main_box.set_margin_end(40)

        title = Gtk.Label(label="WrathOS Setup")
        title.add_css_class("wrathos-title")
        title.set_margin_bottom(6)
        self.main_box.append(title)

        subtitle = Gtk.Label(label="SELECT YOUR BUNDLES")
        subtitle.add_css_class("wrathos-subtitle")
        subtitle.set_margin_bottom(6)
        self.main_box.append(subtitle)

        hint = Gtk.Label(
            label="Choose what to install. You can re-run this anytime from the app menu."
        )
        hint.add_css_class("wrathos-hint")
        hint.set_margin_bottom(24)
        self.main_box.append(hint)

        for bundle in BUNDLES:
            card = self.build_bundle_card(bundle)
            self.main_box.append(card)

        self.install_btn = Gtk.Button(label="Install Selected Bundles")
        self.install_btn.add_css_class("install-btn")
        self.install_btn.set_margin_top(20)
        self.install_btn.connect("clicked", self.on_install_clicked)
        self.main_box.append(self.install_btn)

        self.count_label = Gtk.Label()
        self.count_label.add_css_class("wrathos-hint")
        self.count_label.set_margin_top(8)
        self.main_box.append(self.count_label)
        self.update_count_label()

        skip_btn = Gtk.Button(label="Skip for now")
        skip_btn.add_css_class("skip-btn")
        skip_btn.set_margin_top(4)
        skip_btn.connect("clicked", self.on_skip_clicked)
        self.main_box.append(skip_btn)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_child(self.main_box)
        scrolled.set_vexpand(True)
        self.win.set_child(scrolled)

    def build_bundle_card(self, bundle):
        card_box = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, spacing=12
        )
        card_box.set_margin_bottom(8)

        inner = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, spacing=12
        )
        inner.add_css_class("bundle-card")
        inner.set_hexpand(True)

        check = Gtk.CheckButton()
        check.set_active(bundle["default"])
        check.connect("toggled", self.on_bundle_toggled, bundle, inner)
        self.checks[bundle["id"]] = check

        text_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=2
        )
        text_box.set_hexpand(True)

        name_label = Gtk.Label(label=bundle["name"])
        name_label.add_css_class("bundle-name")
        name_label.set_halign(Gtk.Align.START)

        desc_label = Gtk.Label(label=bundle["desc"])
        desc_label.add_css_class("bundle-desc")
        desc_label.set_halign(Gtk.Align.START)

        text_box.append(name_label)
        text_box.append(desc_label)

        installed = bundle["id"] in get_installed_bundles()
        if installed:
            tag_text = "✓ Installed"
            tag_class = "bundle-tag-recommended"
        elif bundle["recommended"]:
            tag_text = "Recommended"
            tag_class = "bundle-tag-recommended"
        else:
            tag_text = "Optional"
            tag_class = "bundle-tag"
        tag_label = Gtk.Label(label=tag_text)
        tag_label.add_css_class(tag_class)
        tag_label.set_valign(Gtk.Align.CENTER)

        inner.append(check)
        inner.append(text_box)
        inner.append(tag_label)

        if bundle["default"]:
            inner.remove_css_class("bundle-card")
            inner.add_css_class("bundle-card-selected")
            desc_label.remove_css_class("bundle-desc")
            desc_label.add_css_class("bundle-desc-selected")

        card_box.append(inner)
        return card_box

    def on_bundle_toggled(self, check, bundle, inner):
        desc_label = (
            inner.get_first_child()
            .get_next_sibling()
            .get_last_child()
        )
        if check.get_active():
            inner.remove_css_class("bundle-card")
            inner.add_css_class("bundle-card-selected")
            desc_label.remove_css_class("bundle-desc")
            desc_label.add_css_class("bundle-desc-selected")
        else:
            inner.remove_css_class("bundle-card-selected")
            inner.add_css_class("bundle-card")
            desc_label.remove_css_class("bundle-desc-selected")
            desc_label.add_css_class("bundle-desc")
        self.update_count_label()

    def update_count_label(self):
        selected = sum(
            1 for b in BUNDLES if self.checks[b["id"]].get_active()
        )
        if selected == 0:
            self.count_label.set_text("No bundles selected")
            self.install_btn.set_sensitive(False)
        else:
            self.install_btn.set_sensitive(True)
            self.count_label.set_text(
                f"Installing {selected} bundle{'s' if selected != 1 else ''}"
                f" · Est. {selected * 2}-{selected * 4} min"
            )

    def on_skip_clicked(self, btn):
        self.build_autostart_view()

    def on_install_clicked(self, btn):
        selected = [
            b for b in BUNDLES if self.checks[b["id"]].get_active()
        ]
        self.build_progress_view(selected)

    def build_progress_view(self, selected):
        self.progress_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=16
        )
        self.progress_box.set_margin_top(60)
        self.progress_box.set_margin_bottom(40)
        self.progress_box.set_margin_start(40)
        self.progress_box.set_margin_end(40)

        title = Gtk.Label(label="Installing bundles...")
        title.add_css_class("wrathos-title")
        title.set_margin_bottom(8)
        self.progress_box.append(title)

        self.progress_bar = Gtk.ProgressBar()
        self.progress_bar.set_margin_top(8)
        self.progress_box.append(self.progress_bar)

        self.progress_label = Gtk.Label(label="Preparing...")
        self.progress_label.add_css_class("progress-label")
        self.progress_box.append(self.progress_label)

        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_monospace(True)
        self.log_buffer = self.log_view.get_buffer()

        scrolled_log = Gtk.ScrolledWindow()
        scrolled_log.set_child(self.log_view)
        scrolled_log.set_vexpand(True)
        scrolled_log.set_min_content_height(200)
        self.progress_box.append(scrolled_log)

        self.win.set_child(self.progress_box)

        thread = threading.Thread(
            target=self.run_installs, args=(selected,)
        )
        thread.daemon = True
        thread.start()

    def log(self, text):
        GLib.idle_add(self._append_log, text)

    def _append_log(self, text):
        end = self.log_buffer.get_end_iter()
        self.log_buffer.insert(end, text + "\n")
        return False

    def set_progress(self, fraction, label):
        GLib.idle_add(self._set_progress, fraction, label)

    def _set_progress(self, fraction, label):
        self.progress_bar.set_fraction(fraction)
        self.progress_label.set_text(label)
        return False

    def run_installs(self, selected):
        bundle_names = [b["name"] for b in selected]
        all_packages = []
        flatpak_apps = []
        for b in selected:
            all_packages.extend(b.get("packages", []))
            flatpak_apps.extend(b.get("flatpak", []))
        all_packages = list(dict.fromkeys(all_packages))

        self.set_progress(0.1, "Preparing installation...")
        self.log(f"→ Installing: {', '.join(bundle_names)}")
        self.log("Please authenticate when prompted...")

        # Write a single install script
        import os
        script = "/tmp/wrathos-install.sh"
        with open(script, 'w') as f:
            f.write("#!/bin/bash\nset -e\n")
            if all_packages:
                f.write(f"apt-get install -y {' '.join(all_packages)}\n")
            if flatpak_apps:
                f.write("flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo\n")
                for app_id, app_name in flatpak_apps:
                    f.write(f"flatpak install -y --noninteractive --system flathub {app_id}\n")
        os.chmod(script, 0o755)

        try:
            result = subprocess.run(
                ["pkexec", "bash", script],
                capture_output=True,
                text=True,
                timeout=900
            )
            if result.returncode == 0:
                self.set_progress(0.9, "Installation complete...")
                self.log("✓ All packages installed successfully.")
                mark_installed([b["id"] for b in selected])
            else:
                self.log(f"✗ Installation failed:\n{result.stderr[:400]}")
                self.set_progress(1.0, "Installation failed.")
                GLib.idle_add(self.build_done_view)
                return
        except subprocess.TimeoutExpired:
            self.log("✗ Installation timed out after 15 minutes.")
            self.set_progress(1.0, "Timed out.")
            GLib.idle_add(self.build_done_view)
            return
        except Exception as e:
            self.log(f"✗ Error: {e}")
            self.set_progress(1.0, "Error.")
            GLib.idle_add(self.build_done_view)
            return

        self.set_progress(1.0, "Installation complete.")
        self.log("\n✓ All done!")
        GLib.idle_add(self.build_done_view)

    def build_done_view(self):
        done_box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=16
        )
        done_box.set_margin_top(60)
        done_box.set_margin_bottom(40)
        done_box.set_margin_start(40)
        done_box.set_margin_end(40)
        done_box.set_valign(Gtk.Align.CENTER)

        done_label = Gtk.Label(label="✓ Bundles Installed")
        done_label.add_css_class("done-label")
        done_box.append(done_label)

        sub = Gtk.Label(label="Your selected bundles have been installed.")
        sub.add_css_class("wrathos-hint")
        done_box.append(sub)

        next_btn = Gtk.Button(label="Continue")
        next_btn.add_css_class("install-btn")
        next_btn.set_margin_top(24)
        next_btn.connect("clicked", lambda b: self.build_autostart_view())
        done_box.append(next_btn)

        self.win.set_child(done_box)
        return False

    def build_autostart_view(self):
        box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=16
        )
        box.set_margin_top(80)
        box.set_margin_bottom(40)
        box.set_margin_start(50)
        box.set_margin_end(50)
        box.set_valign(Gtk.Align.CENTER)

        title = Gtk.Label(label="Launch at startup?")
        title.add_css_class("wrathos-title")
        box.append(title)

        desc = Gtk.Label(
            label="Would you like WrathOS Setup to open automatically\n"
                  "each time you log in?"
        )
        desc.add_css_class("autostart-label")
        desc.set_justify(Gtk.Justification.CENTER)
        box.append(desc)

        hint = Gtk.Label(
            label="You can always re-run it from the application menu."
        )
        hint.add_css_class("autostart-hint")
        hint.set_margin_bottom(16)
        box.append(hint)

        btn_box = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, spacing=12
        )
        btn_box.set_halign(Gtk.Align.CENTER)

        yes_btn = Gtk.Button(label="Yes, launch at startup")
        yes_btn.add_css_class("yes-btn")
        yes_btn.connect("clicked", self.on_autostart_yes)

        no_btn = Gtk.Button(label="No thanks")
        no_btn.add_css_class("no-btn")
        no_btn.connect("clicked", self.on_autostart_no)

        btn_box.append(yes_btn)
        btn_box.append(no_btn)
        box.append(btn_box)

        self.win.set_child(box)

    def on_autostart_yes(self, btn):
        os.makedirs(os.path.dirname(AUTOSTART_FILE), exist_ok=True)
        with open(AUTOSTART_FILE, 'w') as f:
            f.write(AUTOSTART_CONTENT)
        self.build_farewell_view()

    def on_autostart_no(self, btn):
        if os.path.exists(AUTOSTART_FILE):
            os.remove(AUTOSTART_FILE)
        self.build_farewell_view()

    def build_farewell_view(self):
        box = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=16
        )
        box.set_margin_top(80)
        box.set_margin_bottom(40)
        box.set_margin_start(50)
        box.set_margin_end(50)
        box.set_valign(Gtk.Align.CENTER)

        done = Gtk.Label(label="✓ All done")
        done.add_css_class("done-label")
        box.append(done)

        sub = Gtk.Label(
            label="WrathOS Setup.\nForging ahead reliably, Gaming at the edge."
        )
        sub.add_css_class("wrathos-hint")
        sub.set_justify(Gtk.Justification.CENTER)
        box.append(sub)

        close_btn = Gtk.Button(label="Get Started")
        close_btn.add_css_class("install-btn")
        close_btn.set_margin_top(24)
        close_btn.connect("clicked", lambda b: self.win.close())
        box.append(close_btn)

        self.win.set_child(box)

def main():
    app = WrathOSConfigurator()
    app.run(sys.argv)

if __name__ == "__main__":
    main()
