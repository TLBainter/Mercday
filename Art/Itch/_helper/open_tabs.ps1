param([int]$Start = 0, [int]$Count = 10, [int]$DelaySec = 12)
$urls = Get-Content "$PSScriptRoot\..\tab_urls.txt" | Where-Object { $_ -match 'itch\.io/.+/download/' }
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$slice = $urls | Select-Object -Skip $Start -First $Count
foreach ($u in $slice) {
    Start-Process $chrome -ArgumentList $u
    Start-Sleep -Seconds $DelaySec
}
"Opened $($slice.Count) of $($urls.Count) (next -Start $($Start + $Count))"
