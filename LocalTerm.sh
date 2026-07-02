#!/bin/bash

# ==============================================================================
# 1. SYSTEM-PRÜFUNG & SYSTEM-INSTALLATION (Hintergrund)
# ==============================================================================

# Überprüfen, ob die kritischen Systempakete installiert sind
if ! dpkg -s python3-gi gir1.2-vte-2.91 picocom telnet openssh-client >/dev/null 2>&1; then
    # Grafische Passwortabfrage für den Nutzer
    pkexec sh -c 'apt update && apt install -y python3 python3-gi gir1.2-vte-2.91 picocom telnet openssh-client'
    
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

# ==============================================================================
# 2. TIEFE SYSTEM-INTEGRATION (Wie Firefox / Spotify)
# ==============================================================================

# Ordner für eigene Programme im Benutzerverzeichnis erstellen, falls nicht vorhanden
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/applications"

TARGET_BIN="$HOME/.local/bin/LocalTerm-engine"

# PRÜFUNG: Wird das Skript direkt über eine Pipeline (curl | bash) ausgeführt?
if [ "$0" = "bash" ] || [ "$0" = "-bash" ]; then
    # Wenn es gestreamt wird, laden wir es direkt mit curl an den Zielort herunter
    curl -sL https://raw.githubusercontent.com/Patrick-8372/LocalTerm/refs/heads/main/LocalTerm.sh -o "$TARGET_BIN"
else
    # Wenn es lokal als Datei ausgeführt wird, kopieren wir es ganz normal
    cp "$0" "$TARGET_BIN"
fi

chmod +x "$TARGET_BIN"

# Erstelle die offizielle Desktop-Anwendungsdatei (XDG-Standard)
cat <<EOF > "$HOME/.local/share/applications/LocalTerm.desktop"
[Desktop Entry]
Name=LocalTerm
Comment=Alternative für Switche & Router
Exec=$HOME/.local/share/applications/launch-LocalTerm.sh
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Development;Network;System;
StartupNotify=true
EOF

# Hilfs-Starter erstellen, der den Python-Teil isoliert aufruft
cat <<EOF > "$HOME/.local/share/applications/launch-LocalTerm.sh"
#!/bin/bash
$TARGET_BIN --run-gui
EOF
chmod +x "$HOME/.local/share/applications/launch-LocalTerm.sh"

# Aktualisiere die Desktop-Datenbank des Systems
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications"
fi


# ==============================================================================
# 3. KONTROLL-WEICHE & DIE PYTHON GUI ENGINE
# ==============================================================================

# Wenn das Skript normal angeklickt wird, installiert es sich zuerst und startet dann.
# Der Hilfs-Starter springt über '--run-gui' direkt zum Python-Teil.
if [ "$1" != "--run-gui" ]; then
    # Falls es der Erstaufruf war, zeigen wir dem Nutzer, dass es im System registriert wurde
    # Danach starten wir die GUI
    exec "$TARGET_BIN" --run-gui
fi

# Ab hier läuft die reine Python-App
python3 - << 'EOF'
import sys
import glob
import os
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Vte', '2.91')
from gi.repository import Gtk, Vte, GLib, Gdk

class LocalTermV4(Gtk.Window):
    def __init__(self):
        super().__init__(title="LocalTerm V4 - Native Engine")
        self.set_default_size(1100, 650)
        
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.add(self.main_box)
        
        self.top_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.main_box.pack_start(self.top_bar, False, False, 5)
        
        self.type_combo = Gtk.ComboBoxText()
        self.type_combo.append_text("🔌 Seriell")
        self.type_combo.append_text("⚡ SSH")
        self.type_combo.append_text("🌐 Telnet")
        self.type_combo.set_active(0)
        self.type_combo.connect("changed", self.on_type_changed)
        self.top_bar.pack_start(self.type_combo, False, False, 5)
        
        self.target_combo = Gtk.ComboBoxText()
        self.top_bar.pack_start(self.target_combo, False, False, 5)
        
        self.user_label = Gtk.Label(label="User:")
        self.top_bar.pack_start(self.user_label, False, False, 2)
        self.user_entry = Gtk.Entry()
        self.user_entry.set_text("root")
        self.user_entry.set_width_chars(12)
        self.top_bar.pack_start(self.user_entry, False, False, 5)
        
        self.ip_label = Gtk.Label(label="Host:")
        self.top_bar.pack_start(self.ip_label, False, False, 2)
        self.ip_entry = Gtk.Entry()
        self.ip_entry.set_text("0.0.0.0")
        self.top_bar.pack_start(self.ip_entry, True, True, 5)
        
        self.connect_btn = Gtk.Button(label="Verbinden")
        self.connect_btn.connect("clicked", self.create_terminal_tab)
        self.top_bar.pack_start(self.connect_btn, False, False, 5)
        
        self.notebook = Gtk.Notebook()
        self.notebook.set_scrollable(True)
        self.main_box.pack_start(self.notebook, True, True, 0)
        
        self.refresh_serial_ports()
        self.on_type_changed(self.type_combo)
        
        self.show_all()
        
    def refresh_serial_ports(self):
        self.target_combo.remove_all()
        all_ports = glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*') + glob.glob('/dev/*Switch*')
        
        clean_ports = []
        seen_numbers = set()
        all_ports.sort()
        
        for port in all_ports:
            port_name = port.lower()
            number_match = ''.join(filter(str.isdigit, port))
            
            if "switch" in port_name:
                clean_ports = [p for p in clean_ports if not p.endswith(number_match)]
                clean_ports.append(port)
                if number_match: seen_numbers.add(number_match)
            elif "usb" in port_name or "acm" in port_name:
                if number_match not in seen_numbers:
                    clean_ports.append(port)
                    if number_match: seen_numbers.add(number_match)
                    
        if clean_ports:
            clean_ports.sort()
            for port in clean_ports:
                self.target_combo.append_text(port)
            self.target_combo.set_active(0)
        else:
            self.target_combo.append_text("Keine aktiven Switche gefunden")
            self.target_combo.set_active(0)

    def on_type_changed(self, combo):
        active = combo.get_active_text()
        if active and "Seriell" in active:
            self.refresh_serial_ports()
            self.target_combo.show()
            self.user_label.hide()
            self.user_entry.hide()
            self.ip_label.hide()
            self.ip_entry.hide()
        elif active and "SSH" in active:
            self.target_combo.hide()
            self.user_label.show()
            self.user_entry.show()
            self.ip_label.show()
            self.ip_entry.show()
        else:
            self.target_combo.hide()
            self.user_label.hide()
            self.user_entry.hide()
            self.ip_label.show()
            self.ip_entry.show()

    def create_terminal_tab(self, button):
        conn_type = self.type_combo.get_active_text()
        cwd = os.getcwd()

        if "Seriell" in conn_type:
            port = self.target_combo.get_active_text()
            if not port or "Keine" in port:
                self.show_error_dialog("Bitte wähle einen gültigen seriellen Port aus!")
                return
            command = ["/usr/bin/picocom", "-b", "115200", port]
            tab_label_text = f"🔌 {port.split('/')[-1]}"
        elif "SSH" in conn_type:
            user = self.user_entry.get_text().strip()
            ip = self.ip_entry.get_text().strip()
            if not ip:
                self.show_error_dialog("Bitte gib eine IP-Adresse oder Hostnamen ein!")
                return
            
            if user:
                command = ["/usr/bin/ssh", f"{user}@{ip}"]
                tab_label_text = f"⚡ {user}@{ip}"
            else:
                command = ["/usr/bin/ssh", ip]
                tab_label_text = f"⚡ {ip}"
        else:
            ip = self.ip_entry.get_text().strip()
            if not ip:
                self.show_error_dialog("Bitte gib eine IP-Adresse ein!")
                return
            command = ["/usr/bin/telnet", ip]
            tab_label_text = f"🌐 {ip}"

        terminal = Vte.Terminal()
        
        text_color = Gdk.RGBA()
        text_color.parse("#d8dee9")
        bg_color = Gdk.RGBA()
        bg_color.parse("#2e3440")
        terminal.set_colors(text_color, bg_color, [])
        
        terminal.set_font(gi.repository.Pango.FontDescription.from_string("Monospace 11"))

        tab_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        label = Gtk.Label(label=tab_label_text)
        tab_box.pack_start(label, True, True, 0)
        
        close_btn = Gtk.Button.new_from_icon_name("window-close", Gtk.IconSize.MENU)
        close_btn.set_relief(Gtk.ReliefStyle.NONE)
        tab_box.pack_start(close_btn, False, False, 0)
        tab_box.show_all()

        scroller = Gtk.ScrolledWindow()
        scroller.add(terminal)
        scroller.show_all()

        page_num = self.notebook.append_page(scroller, tab_box)
        close_btn.connect("clicked", lambda b: self.notebook.remove_page(self.notebook.page_num(scroller)))

        try:
            terminal.spawn_sync(
                Vte.PtyFlags.DEFAULT,
                cwd,
                command,
                None,
                GLib.SpawnFlags.DO_NOT_REAP_CHILD,
                None,
                None,
                None
            )
        except Exception as e:
            self.show_error_dialog(f"Fehler beim Starten der Verbindung:\n{str(e)}\n\nIst das Tool (ssh/picocom/telnet) installiert?")
            self.notebook.remove_page(page_num)
            return

        self.notebook.set_current_page(page_num)
        terminal.grab_focus()

    def show_error_dialog(self, message):
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text="Verbindungsfehler"
        )
        dialog.format_secondary_text(message)
        dialog.run()
        dialog.destroy()

if __name__ == "__main__":
    win = LocalTermV4()
    win.connect("destroy", Gtk.main_quit)
    Gtk.main()
EOF

# Copyright (c) 2026 Patrick-8372
#
# Hiermit wird jedem kostenlos das Recht eingeräumt, diese Software zu nutzen,
# zu kopieren, zu verändern und zu verbreiten, unter folgenden Bedingungen:
#
# 1. Der obige Copyright-Hinweis muss in allen Kopien enthalten sein.
# 2. Die kommerzielle Nutzung, der Verkauf oder die kostenpflichtige 
#    Verbreitung dieser Software durch Dritte ist ausdrücklich untersagt.
#
# DIE SOFTWARE WIRD OHNE JEDE GEWÄHRLEISTUNG BEREITGESTELLT, AUSDRÜCKLICH ODER
# IMPLIZIT, EINSCHLIESSLICH, ABER NICHT BESCHRÄNKT AUF DIE GEWÄHRLEISTUNG DER
# MARKTGÄNGIGKEIT, DER EIGNUNG FÜR EINEN BESTIMMTEN ZWECK UND DER NICHTVERLETZUNG
# VON RECHTEN DRITTER. IN KEINEM FALL SIND DIE AUTOREN ODER URHEBERRECHTSINHABER
# FÜR SCHÄDEN ODER ANDERE ANSPRÜCHE HAFTBAR ZU MACHEN.
