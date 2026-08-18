# Änderungen in Version 275

## Backup und Wiederherstellung

- Inkrementelle Backup-ZIPs können jetzt wieder in die App importiert werden. Bei einer Backup-Kette müssen alle zugehörigen ZIP-Dateien gemeinsam ausgewählt werden.
- Vor dem Import können einzelne Inspektionen ausgewählt werden. Andere Projekte und deren Upload-Aufträge bleiben unverändert.
- Neue Backups enthalten neben den Inspektionsdaten auch ausstehende Upload-Aufträge und die bereits bekannten Zuordnungen zwischen lokalen und serverseitigen IDs. Gespeicherte Zugangsdaten werden dabei nicht in das Backup übernommen.
- Der Import wird transaktional ausgeführt: Bei einem Fehler bleibt der vorherige lokale Datenstand erhalten.

## Rettungsimport für Backups aus Version 270

- Für alte v270-Backups gibt es die zusätzliche Option **„v270-Rettung mit Serverabgleich“**.
- Der Rettungsimport vergleicht jede ausgewählte Inspektion mit dem aktuellen Serverstand und rekonstruiert nur noch fehlende Erstellen-, Aktualisieren- und Foto-Uploads.
- Bereits synchronisierte Datensätze werden über ihre Server-ID oder ihren Inhalt erkannt und nicht erneut angelegt.
- Bereits hochgeladene Fotos werden anhand ihres Dateiinhalts erkannt und nicht doppelt übertragen.
- Teilweise synchronisierte Inspektionen können dadurch auf einem neu installierten Gerät fortgesetzt werden.

## Wichtig beim Wechsel von Version 270

Die über GitHub installierte Version 270 kann wegen eines abweichenden Android-Signierschlüssels möglicherweise nicht direkt mit Version 275 überschrieben werden. In diesem Fall:

1. In Version 270 ein aktuelles Backup erstellen und alle ZIP-Dateien der inkrementellen Backup-Kette außerhalb der App sichern.
2. Version 270 deinstallieren und Version 275 installieren.
3. In Version 275 unter „Backups verwalten“ die gesicherten ZIP-Dateien importieren.
4. **„v270-Rettung mit Serverabgleich“** auswählen und die gewünschten Inspektionen markieren.
5. Nach dem Import die App neu öffnen und die normale Synchronisierung starten.

Version 270 hat die ursprünglichen Failed Requests noch nicht in ihre Backup-ZIPs aufgenommen. Der Rettungsimport leitet sie deshalb aus den gesicherten lokalen Daten und dem aktuellen Serverstand ab. Löschvorgänge lassen sich ohne die ursprüngliche Warteschlange nicht zuverlässig rekonstruieren und werden aus Sicherheitsgründen nicht neu erzeugt. Für den Server- und Fotoabgleich ist eine stabile Internetverbindung erforderlich.
