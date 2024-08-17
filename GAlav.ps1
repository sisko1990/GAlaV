# GAlav 1.0.0 (GroupAlarm-Alarmierungsverarbeitung für „EDP Einsatzserver“) © 2024 by Jan Erik Zassenhaus ist lizenziert unter der „BSD 2-Clause“.

$PSDefaultParameterValues['*:Encoding'] = 'utf8'


### Grundeinstellungen vornehmen! - START ###
# Pfad zum Einsatzserver, ohne abschließenden Schrägstrich
$rootDirEinsatzserver = 'C:\EDP\Einsatzserver'

# Pfad zum vom Einsatzserver überwachten Ordner, ohne abschließenden Schrägstrich
$rootDirEinsatzdaten = 'C:\EDP\einsatzdaten'

# Persönlicher API-Schlüssel aus GroupAlarm
$personalGroupAlarmApiKey = 'XXX'
### Grundeinstellungen vornehmen! - ENDE ###


Write-Host 'GAlav 1.0.0 (GroupAlarm-Alarmierungsverarbeitung für „EDP Einsatzserver“) © 2024 by Jan Erik Zassenhaus'
Write-Host 'ist lizenziert unter der „BSD 2-Clause“.'
Write-Host '######################################################'

### Ordnerüberwachung ###

# Zu überwachenden Ordner angeben
$oldDirEinsatzserver = "$rootDirEinsatzserver\old"
$FileSystemWatcher = New-Object System.IO.FileSystemWatcher $oldDirEinsatzserver

# Manueller Abbruch der Schleife
Write-Host '# Mit STRG+C kann das Monitoring abgebrochen werden! #'
Write-Host '######################################################'
Write-Host ''
Write-Host 'Monitoring-Start:' (Get-Date).ToString()

while ($true)
{
    $result = $FileSystemWatcher.WaitForChanged('Created', '10')
    if ($result.TimedOut -eq $false)
    {
        # Äderungen am Verzeichnis könnten mit nachfolgender Zeile ausgegeben werden
        #Write-Warning (‚File {0} : {1}‘ -f $result.ChangeType, $result.name)


        ### API-Abfragen ###
        $authHeader = @{
                    "Personal-Access-Token" = $personalGroupAlarmApiKey
                    }

        $groupalarm_json = Invoke-RestMethod -Uri https://app.groupalarm.com/api/v1/alarms/alarmed -Headers $authHeader
        #$groupalarm_json = Get-Content ".\GroupAlarm-API.txt" | ConvertFrom-Json


        ### Datei für EDP schreiben ###
        if ([int]$groupalarm_json.totalAlarms -gt 0)
        {
            foreach ($alarm in $groupalarm_json.alarms)
            {
                # ID auslesen und als Dateiname speichern, vorher prüfen, ob es die Datei schon gibt. Wenn Ja, fertig, sonst Bearbeitung.
                $alarmId = $alarm.id
                $alarmFilename = "$alarmId.txt"

                if (!(Test-Path "$rootDirEinsatzdaten\old\$alarmFilename"))
                {
                    # ID ist neu; Nachricht auswerten
                    Write-Host (Get-Date).ToString() ": Neuen Alarm mit ID $alarmId verarbeiten!"

                    $alarmMessage = $alarm.message
                    $alarmMessageArray = $alarmMessage.Split([Environment]::NewLine)
                    # Inhalt $alarmMessageArray:
                    ## 0: Meldebild
                    ## 1: Schlagwort
                    ## 2: (leer)
                    ## 3: Straße
                    ## 4: Ort, oft aber Ortsteil
                    ## 5: Objekt oder (leer)
                    ## 6: (leer)
                    ## 7: Bemerkung"# Einsatznummer:"XXX

                    # Grunddaten
                    $alarmOutput = 'Meldebild: ' + $alarmMessageArray[0] + [Environment]::NewLine
                    $alarmOutput += 'Schlagwort: ' + $alarmMessageArray[1] + [Environment]::NewLine
                    $alarmOutput += 'Strasse: ' + $alarmMessageArray[3] + [Environment]::NewLine
                    $alarmOutput += 'Ort: ' + $alarmMessageArray[4] + [Environment]::NewLine

                    # Objekt und Stockwerk/Station voneinander trennen
                    $objectFloorArray = $alarmMessageArray[5].Split('/')
                    $alarmOutput += 'Objekt: ' + $objectFloorArray[0] + [Environment]::NewLine
                    $alarmOutput += 'Stockwerk: ' + $objectFloorArray[1] + [Environment]::NewLine

                    # Bemerkung und Einsatznummer trennen
                    $noteCaseArray = $alarmMessageArray[7].Split('#').Trim()
                    $alarmOutput += 'Bemerkung: ' + $noteCaseArray[0] + [Environment]::NewLine
                    $alarmOutput += $noteCaseArray[1] + [Environment]::NewLine

                    # Rettungsmittel
                    $alarmOutput += $alarm.alarmResources.scenarios.units.name

                    # Ausgabe in Datei schreiben
                    $alarmOutput > "$rootDirEinsatzdaten\$alarmFilename"

                    # Nach der Ausgabe warten, bis der EDP Einsatzserver die Datei verarbeitet hat (und damit auch verschiebt in /old)
                    Start-Sleep -Seconds 5
                }
                else
                {
                    Write-Host (Get-Date).ToString() ": Alarm mit ID $alarmId bereits verarbeitet!"
                }
            }
        }
        else
        {
            Write-Host (Get-Date).ToString() ': Keine Alarme durch GroupAlarm-API zurückgegeben!'
        }
    }
}