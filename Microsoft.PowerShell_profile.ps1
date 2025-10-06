# Configure prompt
function prompt {
    $currentDateTime = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    $user = [Environment]::UserName
    $hostName = [Environment]::MachineName
    $currentPath = Get-Location

    # Colors
    Write-Host -NoNewline -ForegroundColor Magenta "$currentDateTime "
    Write-Host -NoNewline -ForegroundColor DarkRed "$user@$hostName "
    Write-Host -NoNewline -ForegroundColor Blue "$currentPath "
    Write-Host -NoNewline -ForegroundColor White "->"
    return " "
}

# $PSROptions = @{
#     ContinuationPrompt = " "
#     Colors = @{
#         Operator = $PSStyle.Foreground.Magenta
#         Parameter = $PSStyle.Foreground.Magenta
#         InLinePrediction = $PSStyle.Foreground.DarkGrey + $PSStyle.Background.BrightBlack
#     }
# }
# Set-PSReadLineOption @PSROptions
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView

Set-Alias .. Set-Location
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function ll {
    Get-ChildItem -Force | Sort-Object { -not $_.PSIsContainer }, Name | Format-Table Mode, LastWriteTime, Length, Name
}
function ducks {
    Get-ChildItem | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum

        $hrSize = switch ($size) {
            {$_ -ge 1GB} { "{0:N1} GB" -f ($size/1GB); break }
            {$_ -ge 1MB} { "{0:N1} MB" -f ($size/1MB); break }
            {$_ -ge 1KB} { "{0:N1} KB" -f ($size/1KB); break }
            default { "-" }
        }

        return [PSCustomObject]@{
            Name = $_.Name
            Size = $hrSize
            RawSize = $size
        }
    } | Sort-Object RawSize -Descending | Format-Table Name, Size
}
