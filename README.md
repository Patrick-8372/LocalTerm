### Wichtiger Hinweis für serielle Verbindungen (USB)

Sollte die serielle Nutzung zu Problemen (z. B. "Permission Denied") führen, fehlen deinem Linux-Nutzer die Rechte für die Schnittstelle. Das kannst du mit folgendem Befehl im Terminal beheben:

```bash
sudo usermod -aG dialout $USER
```
## Installation

```bash
curl -sL [https://raw.githubusercontent.com/Patrick-8372/LocalTerm/refs/heads/main/LocalTerm.sh](https://raw.githubusercontent.com/Patrick-8372/LocalTerm/refs/heads/main/LocalTerm.sh) | bash
```
