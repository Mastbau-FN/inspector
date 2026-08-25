# Änderungen in Version 281

## Performance und Bedienung

- Die Mängelprüfung vor dem Öffnen einer Inspektion verarbeitet Backend-Abfragen begrenzt parallel. Inspektionen mit vielen Prüfpunkten öffnen sich dadurch deutlich schneller.
- Nach einem bereits abgeschlossenen Zoom-Fokus wiederholt die Kamera die Fokus- und Belichtungsaufrufe beim Auslösen nicht mehr unnötig.
- Während eines Foto-Uploads zeigt die Galerie lokale und bereits zugeordnete Server-Referenzen desselben Bildes nicht mehr vorübergehend doppelt an.
- Frisch aufgenommene und bereits hochgeladene Bilder lassen sich direkt aus der Galerie teilen.
- Die Standortkarte lädt OpenStreetMap-Kacheln wieder zuverlässig mit korrekter App-Kennung.
- Online angelegte Prüfkategorien und Prüfpunkte speichern ihren Ersteller. Die Aktionen zum Bearbeiten und Löschen bleiben dadurch auch nach einem Neustart verfügbar.

## Offline-Downloads

- Versehentlich als Bilder hinterlegte Server-Altlasten wie `Thumbs.db`, `Desktop.ini` oder `.DS_Store` werden beim Herunterladen übersprungen. Eine ansonsten vollständig geladene Inspektion wird dadurch nicht mehr fälschlich als fehlgeschlagen markiert.
- Der grüne Offline-Status einer heruntergeladenen Inspektion bleibt nach App-Neustarts und beim Aktualisieren der Inspektionsliste erhalten.
