import os

# Verzeichnis mit den Code-Dateien
verzeichnis = './'

# Zieldatei
zieldatei = 'alle_codes.txt'

# Dateiendung der Code-Dateien, z.B. '.py', '.js'
dateiendung = '.dart'

def sammle_dateien(verzeichnis):
    """Durchsucht das Verzeichnis rekursiv nach Dateien mit der angegebenen Endung."""
    gefundene_dateien = []
    for root, _, files in os.walk(verzeichnis):
        for file in files:
            if file.endswith(dateiendung):
                gefundene_dateien.append(os.path.join(root, file))
    return gefundene_dateien

# Alle passenden Dateien rekursiv sammeln
dateien_liste = sammle_dateien(verzeichnis)

# Zusammenfügen der Dateien in eine einzelne Datei
with open(zieldatei, 'w', encoding='utf-8') as outfile:
    for dateipfad in dateien_liste:
        with open(dateipfad, 'r', encoding='utf-8') as infile:
            outfile.write(f'// Inhalt von {dateipfad}\n')
            outfile.write(infile.read())
            outfile.write('\n\n')

print(f'Alle Dateien wurden in {zieldatei} zusammengeführt.')
