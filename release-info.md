# Änderungen in Version 275

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

## Wechsel von Version 270 auf Version 275

Die über GitHub installierte Version 270 kann wegen eines abweichenden Android-Signierschlüssels möglicherweise nicht direkt aktualisiert werden. In diesem Fall:

1. In Version 270 ein neues vollständiges Backup erstellen.
2. Alle ZIP-Dateien der Backup-Kette außerhalb der App sichern.
3. Version 270 deinstallieren und Version 275 installieren.
4. In Version 275 unter **„Backups verwalten“** alle ZIP-Dateien der Kette auswählen.
5. **„v270-Rettung mit Serverabgleich“** wählen und die benötigten Inspektionen markieren.
6. Nach dem erfolgreichen Import die normale Synchronisierung starten.

Für den Server- und Fotoabgleich ist eine stabile Internetverbindung erforderlich. Die Backup-ZIPs sollten bis zum vollständig abgeschlossenen Sync auf einem zweiten Gerät oder Computer aufbewahrt werden.
