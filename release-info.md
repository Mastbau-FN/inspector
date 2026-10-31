# Änderungen in Version 287

## Android

- Der Release verwendet denselben Flutter-Stand wie die auf dem Inspektionshandy geprüfte App.
- Android 7.0 (API 24) oder neuer wird benötigt.

## Kamera

- Haupt- und Selfie-Kamera zeigen eine aufrechte Vorschau mit korrekten Bildproportionen.
- Selfies bleiben von der Live-Vorschau über die Aufnahmevorschau bis zur gespeicherten Datei gespiegelt.
- Nach dem Auslösen erscheint während der Verarbeitung die Ladeanzeige; der kurzzeitig rote Fehlerbildschirm entfällt.
- Abbrechen und Schließen während einer Aufnahme sind abgesichert. Zwischenzeitlich ausgewählte Bilder werden nicht von einer verspäteten Aufnahme überschrieben.
- Kameraschalter, Blitz und Zoom bleiben auch bei wenig verfügbarer Höhe vollständig sichtbar.

## Dokumente

- Dokumente aus zugewiesenen Inspektionen einschließlich ihrer Kategorien, Prüfpunkte und Mängel lassen sich sicher herunterladen.
- Downloads werden gestreamt. Nicht erreichbare Projektablagen werden als Speicherfehler gemeldet, statt als erfolgreiche leere Liste zu erscheinen.
- Foto-freie Untereinträge bleiben lesbar, solange die zugehörige Inspektionsablage erreichbar ist.

## Backend

- Der Server verwendet Node.js 24.
- Fehler, langsame Anfragen und Datenbankprobleme sind über Request-IDs zuordenbar; Zugangsdaten werden dabei nicht protokolliert.
- Der Neustart bricht bei fehlgeschlagener Git-Aktualisierung oder ungültiger Serverkonfiguration vor dem Dienstwechsel ab.
