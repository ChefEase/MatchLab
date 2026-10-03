# Checks the football-data.org Free account against MatchLab Task 1.
# Uses only built-in PowerShell commands. Never prints or saves the API token.

$ErrorActionPreference = 'Stop'
$baseUrl = 'https://api.football-data.org/v4'
$secureToken = Read-Host 'Paste your football-data.org API token (input hidden)' -AsSecureString
$tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
try {
    $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
}

if ([string]::IsNullOrWhiteSpace($plainToken)) {
    throw 'No token entered.'
}

$headers = @{ 'X-Auth-Token' = $plainToken }
$plainToken = $null

function Get-FootballData {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        return Invoke-RestMethod -Method Get -Uri "$baseUrl$Path" -Headers $headers -TimeoutSec 30
    }
    catch {
        $code = 'request failed'
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
        }
        Write-Warning "$Path : $code"
        return $null
    }
}

try {
    $competition = Get-FootballData '/competitions/PL'
    if ($null -eq $competition) {
        throw 'EPL competition request failed. Check that the token is active and EPL is included.'
    }

    $startYear = ([datetime]$competition.currentSeason.startDate).Year
    Write-Output "Competition: $($competition.name) (code $($competition.code))"
    Write-Output "Current season start year: $startYear"
    Write-Output 'Season audit (a completed EPL season normally has 380 matches):'

    $seasonRows = @()
    foreach ($year in (($startYear - 3)..$startYear)) {
        $response = Get-FootballData "/competitions/PL/matches?season=$year"
        if ($null -eq $response -or $null -eq $response.matches) {
            $seasonRows += [pscustomobject]@{
                Season = "$year/$($year + 1)"
                Matches = 'unavailable'
                FinishedWithScores = '-'
                MissingTeamIds = '-'
                Future = '-'
            }
            continue
        }

        $matches = @($response.matches)
        $withScores = @($matches | Where-Object {
            $_.status -eq 'FINISHED' -and
            $null -ne $_.score.fullTime.home -and
            $null -ne $_.score.fullTime.away
        }).Count
        $missingTeams = @($matches | Where-Object {
            $null -eq $_.homeTeam.id -or $null -eq $_.awayTeam.id
        }).Count
        $future = @($matches | Where-Object {
            $_.utcDate -and ([datetime]$_.utcDate).ToUniversalTime() -gt [datetime]::UtcNow
        }).Count

        $seasonRows += [pscustomobject]@{
            Season = "$year/$($year + 1)"
            Matches = $matches.Count
            FinishedWithScores = $withScores
            MissingTeamIds = $missingTeams
            Future = $future
        }
    }

    $seasonRows | Format-Table -AutoSize | Out-String | Write-Output
    Write-Output 'Share only the table above. Never share the API token.'
}
finally {
    $headers['X-Auth-Token'] = $null
    Remove-Variable secureToken, headers -ErrorAction SilentlyContinue
}
