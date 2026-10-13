# Linux-Café Ebersbach - Linux Mirror

Diese Maschine stellt einen lokalen apt-Mirror sowie ein Hilfsskript für Updates zur Verfügung.

## Führen Sie dies auf Ihrem Client-Rechner aus

```bash
curl -fsSL http://linux-mirror/setup.sh | bash -s -- run
```

## Was es macht

- apt-Quellen werden auf den lokalen Mirror umgeschrieben
- apt update wird ausgeführt
- Upgrade-Schritte werden ausgeführt
- zusätzliche Pakete werden installiert
- optionale Pakete werden interaktiv installiert
- Systemeinstellungen werden auf sinnvolle Standardwerte geändert

## Hinweise

- führen Sie das Skript als Benutzer mit sudo-Berechtigung aus
- prüfen Sie das Skript vorher, falls gewünscht:

```bash
curl -fsSL http://linux-mirror/setup.sh
```

- Sie können es auch als Probelauf ausführen (das Skript wird vollständig simuliert, ohne Änderungen an Ihrem System vorzunehmen):

```bash
curl -fsSL http://linux-mirror/setup.sh | bash -s -- run --dry-run
```

- oder laden Sie es herunter:

```bash
curl -fsSLO http://linux-mirror/setup.sh
```

## Festlegen aller Einstellungen / Installation zusätzlicher Programme

Hierfür wir eine Internetverbindung benötigt.

```bash
sudo apt-get update && sudo apt-get install -y git && \
tmp_repo="$(mktemp -d -p "${TMPDIR:-/tmp}" lcafe.XXXXXXXX)" && \
trap 'rm -rf -- "$tmp_repo"' EXIT && \
git clone --depth 1 https://github.com/timhansinger/linux-cafe-ebersbach-linux-mint-cinnamon-post-install-script "$tmp_repo" && \
bash "$tmp_repo/run.sh"
```

