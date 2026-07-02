### Wichtiger Hinweis für serielle Verbindungen (USB)

Sollte die serielle Nutzung zu Problemen (z. B. "Permission Denied") führen, fehlen deinem Linux-Nutzer die Rechte für die Schnittstelle. Das kannst du mit folgendem Befehl im Terminal beheben:

```bash
sudo usermod -aG dialout $USER
