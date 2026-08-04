# Snap Par

Snap Par ist ein lokales Android Golfspiel mit Godot 4.3. Ein Foto wird in ein spielbares Terrain umgewandelt. Dunkle Bereiche bilden feste Flächen, helle Bereiche bilden freien Raum. Farbe und Helligkeit bestimmen Fels, Sand, Eis, Wasser und Luft. Eine Runde besteht aus drei Fotos und drei Löchern.

## Datenschutz und Berechtigungen

* Keine Serverkommunikation
* Keine Werbung
* Keine Analytics
* Keine Netzwerkbibliothek
* Keine Berechtigung `INTERNET`
* Kamera und Galerie werden über Android Systemdialoge geöffnet
* Fotos, Bestleistung und Collagen bleiben lokal auf dem Gerät

Der Build Workflow prüft die fertige Debug APK zusätzlich mit `aapt` und bricht ab, falls `android.permission.INTERNET` enthalten ist.

## Projektstruktur

```text
scenes/                       Spiel und Bildschirme
scripts/                      Terrain, Physik, Ablauf und Effekte
scripts/tests/                Headless Tests für die Terrain Analyse
assets/                       Lokales Testbild und App Ressourcen
plugin/                       Quellcode des Android Medienplugins
addons/SnapParAndroid/        Godot Exportplugin, AAR Dateien entstehen im Build
.github/workflows/build.yml   APK und AAB Build
```

## Terrain Pipeline

1. Das Foto wird auf das Hochformat zugeschnitten und auf 108 x 192 Zellen skaliert.
2. Ein adaptiver Grauwert Schwellwert sucht einen Festanteil zwischen 35 und 45 Prozent.
3. Feste Komponenten unter acht Zellen werden entfernt.
4. Einzelne freie Löcher, die komplett von festen Zellen umgeben sind, werden gefüllt.
5. Ein Flood Fill sucht die grösste zusammenhängende Luftfläche.
6. Der Ball startet weit oben in dieser Fläche.
7. Das Loch liegt in der davon am weitesten entfernten erreichbaren Zelle.
8. Ist die sichere Fläche kleiner als 15 Prozent, wird das Foto abgelehnt.

### Materialien

| Zelltyp | Erkennung | Reibung | Rückprall | Verhalten |
|---|---|---:|---:|---|
| Sand | Hue 20 bis 60, Sättigung über 0.30 | 0.95 | 0.05 | Ball versandet |
| Eis | Sättigung unter 0.15, Wert über 0.75 | 0.02 | 0.30 | Ball rutscht weit |
| Fels | übrige feste Zellen | 0.60 | 0.40 | normaler harter Kontakt |
| Wasser | Hue 180 bis 260, Sättigung über 0.25 | keine Kollision | keine | Strafschlag und Rücksetzung |
| Luft | übrige freie Zellen | keine Kollision | keine | freier Raum |

## Lokal starten

Voraussetzungen:

* Godot 4.3
* OpenJDK 17
* Android SDK Platform und Build Tools 34
* Gradle 8.7 oder ein kompatibler Gradle Wrapper

1. Android Plugin bauen:

   ```bash
   gradle :plugin:packagePlugin
   ```

2. Projekt in Godot 4.3 öffnen.
3. Unter `Projekt > Android Build Template installieren` die Android Vorlage installieren.
4. `scenes/Boot.tscn` starten.
5. Auf Desktop verwendet `Foto machen` automatisch das lokale Testbild. `Aus Galerie` öffnet einen nativen Dateidialog.

## Tests

```bash
godot --headless --path . --script scripts/tests/terrain_tests.gd
```

Enthalten sind zwei deterministische Fälle. Beide prüfen zusätzlich das Ziel von weniger als einer Sekunde Terrain Ladezeit:

1. Graustufen Rauschbild
2. Helles Bild mit einem einzelnen schwarzen Balken

## GitHub Actions

Bei jedem Push auf `main` oder bei manueller Ausführung:

1. Godot 4.3 und die Export Templates werden geladen.
2. Java 17 und Android SDK 34 werden eingerichtet.
3. Das lokale Android Medienplugin wird als Debug und Release AAR gebaut.
4. Die Terrain Tests laufen headless.
5. Eine Debug APK wird erzeugt.
6. Die APK wird auf eine unerlaubte `INTERNET` Berechtigung geprüft.
7. Die Debug APK wird als Artefakt `snap-par-debug-apk` hochgeladen.

Bei einem Tag `v*` wird zusätzlich ein signiertes AAB als Artefakt `snap-par-release-aab` erzeugt.

## Release Keystore und Secrets einrichten

Der Keystore darf niemals in dieses Repository kopiert oder committed werden.

1. Keystore mit Java 17 erzeugen. Für Godot 4.3 müssen Keystore Passwort und Key Passwort identisch sein.

   ```bash
   keytool -v -genkeypair \
     -keystore snap-par-release.keystore \
     -alias snappar \
     -keyalg RSA \
     -keysize 4096 \
     -validity 10000
   ```

2. Den Keystore an einem sicheren, extern gesicherten Ort ablegen. Ohne diesen Schlüssel können spätere Updates derselben Play Store App nicht signiert werden.

3. Den Keystore als einzeilige Base64 Zeichenfolge codieren.

   Linux:

   ```bash
   base64 -w 0 snap-par-release.keystore
   ```

   macOS:

   ```bash
   base64 < snap-par-release.keystore | tr -d '\n'
   ```

   PowerShell:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("snap-par-release.keystore"))
   ```

4. Im GitHub Repository `Settings > Secrets and variables > Actions` öffnen.

5. Folgende Repository Secrets erstellen:

   | Secret | Inhalt |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | vollständige einzeilige Base64 Zeichenfolge |
   | `ANDROID_KEY_ALIAS` | Alias aus dem Keytool Befehl, standardmässig `snappar` |
   | `ANDROID_KEYSTORE_PASSWORD` | Keystore Passwort |
   | `ANDROID_KEY_PASSWORD` | identisches Key Passwort |

6. Niemals die Base64 Zeichenfolge, Passwörter oder die Datei in Logs, Issues oder Commits einfügen.

7. Einen Release Build auslösen:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

8. In GitHub unter `Actions > Android Build` den erfolgreichen Lauf öffnen und das Artefakt `snap-par-release-aab` herunterladen.

9. Das AAB in der Google Play Console hochladen. Die Debug APK ist nur zum Testen und darf nicht als Produktionsrelease verwendet werden.

## Game Feel

* Kurze Vibration beim Schlag und beim Einlochen
* Materialabhängige, lokal erzeugte Kontaktgeräusche
* Tiefes Sandgeräusch, heller Eiskontakt und Wasserplatschen
* Dezentes Umgebungsgeräusch nur während des Spiels
* 0.3 Sekunden Zeitlupe bei einem Beinahe Treffer unter 40 Pixel Abstand
* Minimale optische Ballverformung bei einem Aufprall
* Einmalige animierte Handbewegung in der ersten Runde, ohne Tutorial Text

Alle Klänge sind kleine, eigens erzeugte lokale WAV Dateien. Es werden keine Medien aus dem Netzwerk geladen.

## Steuerung

Den ruhenden Ball berühren, entgegen der gewünschten Flugrichtung ziehen und loslassen. Die gepunktete Linie zeigt Richtung und Stärke. Ein neuer Schlag ist erst möglich, wenn der Ball vollständig ruht.
