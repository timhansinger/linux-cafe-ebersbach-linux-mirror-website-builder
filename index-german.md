# Linux-Café Ebersbach - Linux Mirror

Diese Maschine stellt einen lokalen apt-Mirror sowie ein Hilfsskript für Updates zur Verfügung.

## Führen Sie dies auf Ihrem Client-Rechner aus

Mit diesem Befehl werden alle Pakete über den lokalen Mirror aktualisiert.

```bash
curl -fsSL http://linux-mirror.local/setup.sh | bash -s -- run
```

Um **ZUSÄTZICH** auch alle Einstellungen festzulegen / zusätzliche Programme zu installieren bitte diesen Befehl stattdessen verwenden:

```bash
curl -fsSL http://linux-mirror.local/setup.sh | bash -s -- run --post-install
```

Um **NUR** die Einstellungen festzulegen / zusätzliche Programme zu installieren bitte diesen Befehl stattdessen verwenden:

```bash
curl -fsSL http://linux-mirror.local/setup.sh | bash -s -- only-post-install
```

## Was es macht

- apt-Quellen werden auf den lokalen Mirror umgeschrieben
- apt update wird ausgeführt
- Upgrade-Schritte werden ausgeführt
- zusätzliche Pakete werden installiert (bei Verwendung von `post-install`)
- optionale Pakete werden interaktiv installiert (bei Verwendung von `post-install`)
- Systemeinstellungen werden auf sinnvolle Standardwerte geändert (bei Verwendung von `post-install`)
- apt-Quellen werden auf den vorherigen Mirror zurückgesetzt
