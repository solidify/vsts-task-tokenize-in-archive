Function Expand-Variables
{
    [CmdletBinding()]
    param(
        [string] $Text
    )

    $regex = [regex] "\$\(((?:(?!\)).)*)\)"
    $replaceCallback = {
        param(
            [System.Text.RegularExpressions.Match] $Match
        )
        
        Get-TaskVariable $distributedTaskContext $Match.Groups[1].Value
    }

    $maxIteration = 50
    $iteration = 0

    do
    {
        $oldText = $Text
        $Text = $regex.Replace($Text, $replaceCallback)
    }
    while (($Text -ne $oldText) -and (++$iteration -lt $maxIteration))

    if ($iteration -eq $maxIteration)
    {
        Write-Warning "Expand variables: exceeded max iterations."
    }

    $Text
}