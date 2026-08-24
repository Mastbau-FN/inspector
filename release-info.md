# Änderungen in Version 277

Version 275 erweitert die Datensicherung um eine vollständige Wiederherstellung und ermöglicht die Fortsetzung fehlgeschlagener Synchronisierungen nach einem Versionswechsel oder einer Neuinstallation.

## Backup-Import und Wiederherstellung

- Inkrementelle Backup-Ketten können unter **„Backups verwalten“** geprüft und wiederhergestellt werden. Dazu werden alle zusammengehörigen ZIP-Dateien gemeinsam ausgewählt.
- Vor der Wiederherstellung können einzelne Inspektionen ausgewählt werden. Nicht ausgewählte Inspektionen und bereits vorhandene lokale Daten bleiben unverändert.
- Neue Backups sichern neben den Inspektionsdaten auch offene Upload-Aufträge und bekannte Zuordnungen zwischen lokalen und serverseitigen IDs. Zugangsdaten werden weiterhin nicht gesichert.
- Der Import wird transaktional ausgeführt. Schlägt die Prüfung oder Wiederherstellung fehl, bleibt der vorherige lokale Datenbestand erhalten.

## Rettungsimport für Version 270

Für Backups aus Version 270 steht die zusätzliche Option **„v270-Rettung mit Serverabgleich“** zur Verfügung.

- Die ausgewählten Inspektionen werden unmittelbar vor dem Import mit dem aktuellen Serverstand verglichen.
- Fehlende Erstellen-, Aktualisieren- und Foto-Uploads werden als neue offene Upload-Aufträge rekonstruiert.
- Bereits synchronisierte Datensätze werden anhand ihrer Server-ID oder ihres Inhalts erkannt und nicht erneut angelegt.
- Bereits vorhandene Fotos werden anhand ihres Dateiinhalts erkannt und nicht doppelt hochgeladen.
- Eine zuvor unterbrochene Synchronisierung kann dadurch nach dem Import auf dem neuen App-Stand fortgesetzt werden.

Version 270 hat die ursprünglichen offenen Upload-Aufträge noch nicht in das Backup aufgenommen. Sie müssen deshalb aus dem lokalen Datenbestand rekonstruiert werden. Reine Löschaufträge lassen sich ohne die ursprüngliche Warteschlange nicht zuverlässig bestimmen und werden aus Sicherheitsgründen nicht erzeugt.

## Stabilität bei großen Datenmengen

- Große Backup-ZIPs werden beim Prüfen und Wiederherstellen dateiweise gestreamt. Dadurch werden auch Backups mit mehreren Gigabyte nicht mehr vollständig in den Arbeitsspeicher geladen.
- Temporäre Dateien der Android-Dateiauswahl werden nach dem Import entfernt, sodass importierte ZIPs nicht mehrfach Speicherplatz belegen.
- Das HTTP-Timeline-Logging wurde für lange Upload-Läufe deaktiviert. Dadurch bleibt der Speicherverbrauch auch beim Synchronisieren vieler großer Foto-Batches stabil.
- Erfolgreich übertragene Upload-Aufträge werden weiterhin sofort aus der lokalen Warteschlange entfernt. Ein späterer Abbruch setzt deshalb nur die noch offenen Aufträge fort.

## Performance und Fotoanzeige

- Die Mängelprüfung vor dem Öffnen einer Inspektion verarbeitet ihre Backend-Abfragen begrenzt parallel und blockiert die Navigation dadurch deutlich kürzer.
- Nach einem bereits abgeschlossenen Zoom-Fokus wiederholt die Kamera die Fokus- und Belichtungsaufrufe beim Auslösen nicht unnötig.
- Während eines Foto-Uploads zeigt die Galerie lokale und bereits zugeordnete Server-Referenzen desselben Bildes nicht mehr vorübergehend doppelt an.
- Frisch aufgenommene und bereits hochgeladene Bilder lassen sich direkt aus der Galerie teilen.
- Die Standortkarte lädt OpenStreetMap-Kacheln wieder zuverlässig mit korrekter App-Kennung.
- Online angelegte Prüfkategorien und Prüfpunkte speichern den Ersteller, sodass ihre Bearbeiten- und Löschen-Aktionen auch nach einem Neustart erhalten bleiben.
- Offline-Downloads überspringen versehentlich als Bilder referenzierte Server-Altlasten wie `Thumbs.db`, ohne eine ansonsten vollständig geladene Inspektion fälschlich als fehlgeschlagen zu markieren.
