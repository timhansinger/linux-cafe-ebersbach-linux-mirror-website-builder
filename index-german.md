# Linux-Café Ebersbach - Linux Mirror

Diese Maschine stellt einen lokalen apt-Mirror sowie ein Hilfsskript für Updates zur Verfügung.

## Führen Sie dies auf Ihrem Client-Rechner aus

1. `Terminal` öffnen
2. Den folgenden Befehl kopieren
   ```bash
   curl -fsSL http://linux-mirror.local/setup.sh | bash -s -- run --post-install
   ```
3. Im `Terminal` einfügen (`Ctrl` + `Shift` + `V`) und ausführen

## Was es macht

- apt-Quellen werden auf den lokalen Mirror umgeschrieben
- apt update wird ausgeführt
- Upgrade-Schritte werden ausgeführt
- zusätzliche Pakete werden installiert
- optionale Pakete werden interaktiv installiert
- Systemeinstellungen werden auf sinnvolle Standardwerte geändert
- apt-Quellen werden auf einen lokalen öffentlichen Mirror (derzeit: HS Esslingen) gestellt
