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
        "id": "wrathos-bundle-gpu",
        "name": "GPU Drivers",
        "desc": "AMD · NVIDIA · Intel · Vulkan ICD · 32-bit Mesa",
        "recommended": True,
        "default": True,
    },
    {
        "id": "wrathos-bundle-steam",
        "name": "Steam + Proton-GE",
        "desc": "Steam (Flatpak) · Proton-GE · DXVK · VKD3D",
        "recommended": True,
        "default": True,
    },
    {
        "id": "wrathos-bundle-perf",
        "name": "Performance Tools",
        "desc": "GameMode · MangoHud · Gamescope · CoreCtrl",
        "recommended": True,
        "default": True,
    },
    {
        "id": "wrathos-bundle-codecs",
        "name": "Media Codecs",
        "desc": "VLC · FFmpeg · GStreamer · H.264 · H.265 · AAC",
        "recommended": True,
        "default": True,
    },
    {
        "id": "wrathos-bundle-launchers",
        "name": "Game Launchers",
        "desc": "Heroic · Lutris · Bottles · Epic · GOG",
        "recommended": False,
        "default": False,
    },
    {
        "id": "wrathos-bundle-emulation",
        "name": "Emulation",
        "desc": "RetroArch · EmulationStation-DE · Dolphin · RPCS3",
        "recommended": False,
        "default": False,
    },
]

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

        title = Gtk.Label(label="Welcome to WrathOS")
        title.add_css_class("wrathos-title")
        title.set_margin_bottom(6)
        self.main_box.append(title)

        subtitle = Gtk.Label(label="SELECT YOUR GAMING BUNDLES")
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

        tag_label = Gtk.Label(
            label="Recommended" if bundle["recommended"] else "Optional"
        )
        tag_label.add_css_class(
            "bundle-tag-recommended" if bundle["recommended"] else "bundle-tag"
        )
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
        total = len(selected)
        for i, bundle in enumerate(selected):
            self.set_progress(i / total, f"Installing {bundle['name']}...")
            self.log(f"→ Installing {bundle['name']}...")
            try:
                result = subprocess.run(
                    ["pkexec", "apt-get", "install", "-y", bundle["id"]],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    self.log(f"✓ {bundle['name']} installed successfully.")
                else:
                    self.log(
                        f"✗ {bundle['name']} failed: {result.stderr[:200]}"
                    )
            except Exception as e:
                self.log(f"✗ Error installing {bundle['name']}: {e}")

        self.set_progress(1.0, "Installation complete.")
        self.log("\n✓ All done! Enjoy WrathOS.")
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

        sub = Gtk.Label(label="Your gaming bundles have been installed.")
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
            label="Welcome to WrathOS.\nForging ahead reliably, Gaming at the edge."
        )
        sub.add_css_class("wrathos-hint")
        sub.set_justify(Gtk.Justification.CENTER)
        box.append(sub)

        close_btn = Gtk.Button(label="Start Gaming")
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
