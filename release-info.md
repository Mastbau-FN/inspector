# Änderungen

- Android-Updates können wieder direkt über die bereits installierte Version 270 installiert werden. Lokale Builds und GitHub-Releases verwenden dafür denselben geprüften Signierschlüssel.
- In den Auswahllisten zum Anlegen neuer Einträge ist jetzt auch der oberste Punkt zuverlässig anklickbar, selbst wenn die Liste bis an die Statusleiste reicht.
- Inspektionen, die nach der Verarbeitung nicht mehr auf dem Server vorhanden sind, werden bei der nächsten erfolgreichen Serverprüfung vollständig aus der App entfernt. Dazu gehören auch Kategorien, Prüfpunkte, Mängel, Fotos, Dokumente, Sync-Daten und alte Warteschlangeneinträge.
- Noch nicht synchronisierte lokale Offline-Inspektionen bleiben von dieser automatischen Bereinigung geschützt.
- Bereits übertragene und serverseitig entfernte Inspektionen werden nicht mehr aus verbliebenen App-Zwischendaten erneut in neue Backups aufgenommen.
- Inkrementelle Backups berücksichtigen nur noch tatsächliche Änderungen an Inspektionsdaten. Änderungen an Laufzeitdateien, internen Warteschlangen, Bildindizes und App-Assets erzeugen kein unnötiges Backup mehr.
- Wenn es seit dem letzten Backup keine fachlichen Änderungen gab, wird keine neue Backup-Datei erstellt.
- Abgebrochene `backup-*.zip.partial`-Dateien werden beim nächsten Backup automatisch bereinigt. Bereits vorhandene vollständige Backups bleiben erhalten.
