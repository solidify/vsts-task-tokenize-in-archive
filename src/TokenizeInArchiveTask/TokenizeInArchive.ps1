[CmdletBinding()]
param (
)

Trace-VstsEnteringInvocation $MyInvocation

try {
    $PathToArchives = Get-VstsInput -Name PathToArchives -Require
    $Packages = Get-VstsInput -Name Packages -Require
    $FilesToTokenize = Get-VstsInput -Name FilesToTokenize -Require
    $Prefix = Get-VstsInput -Name Prefix
    $Suffix = Get-VstsInput -Name Suffix
    $ReplaceWithEmpty = Get-VstsInput -Name ReplaceWithEmpty

    Write-Verbose "PathToArchives = $PathToArchives" -Verbose
    Write-Verbose "Packages = $Packages" -Verbose
    Write-Verbose "FilesToTokenize = $FilesToTokenize" -Verbose
    Write-Verbose "Prefix = $Prefix" -Verbose
    Write-Verbose "Suffix = $Suffix" -Verbose
    Write-Verbose "ReplaceWithEmpty = $ReplaceWithEmpty" -Verbose

    # Dont think we should do this anymore
    Import-Module -Name "$PSScriptRoot\ps_modules\VstsTaskSdk\VstsTaskSdk.psm1"
    #Import-Module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
    #Import-Module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

    #Based on http://stackoverflow.com/questions/25538501/edit-zip-file-content-in-subfolder-with-powershell

    #. "$PSScriptRoot\HelperFunctions.ps1"

    #$PathToArchives e.g. "C:\Projects\PS\ChangeZip\drop"
    #$Packages e.g. "*.zip"
    #Regex to search for specific file entries in zip
    #$FilesToTokenize e.g. "Web.config"

    Write-Host "Searching for all $Packages files at $PathToArchives"
    Write-Host "Searching for $FilesToTokenize inside $Packages files"

    #Need to find matching keys in the target files and use them to get variable values, because secret keys are not environment variables

    $tokenPrefix = [regex]::Escape($Prefix)
    $tokenSuffix = [regex]::Escape($Suffix)
    $regex = [regex] "${tokenPrefix}((?:(?!${tokenSuffix}).)*)${tokenSuffix}"
    Write-Verbose "regex: ${regex}"

    $ErrorActionPreference = "Stop"

    $zips = Get-ChildItem -Path $PathToArchives -Include $Packages -Recurse

    $replaceWithEmptyText = $False
    if ($ReplaceWithEmpty.ToLowerInvariant() -eq "true") {
        $replaceWithEmptyText = $True
    }

    # Load ZipFile (Compression.FileSystem) if necessary
    try { $null = [IO.Compression.ZipFile] }
    catch { [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') }

    $zips | ForEach-Object {
        $file = $_
        Write-Host "Matched zip: $($_.FullName)"
        # Open zip file with update mode (Update, Read, Create -- are the options)
        try { 
            $fileZip = [System.IO.Compression.ZipFile]::Open( $file, 'Update' ) 
        }
        catch { throw "Another process has locked the '$file' file." }

        # Finding the specific file within the zip file
        <#
        NOTE: These entries have the directories separated with a forward slash (/) instead of MS convention
        of a backward slash (\).  Even though this is regex it seems the forward slash does not need to be escaped (\/).
        NOTE2: Because this is regex '.*' must be used instead of a simple '*'
        #>
        try {
            $matchingFiles = $fileZip.Entries | Where-Object { $_.FullName -match "$FilesToTokenize" }

            $matchingFiles | ForEach-Object {
                $matchingEntry = $_
                Write-Host "Matched file in zip: $($_.FullName)"
                # If needed, read the contents of specific file to $text and release the file so to use streamwriter later
                $desiredFile = [System.IO.StreamReader]($matchingEntry).Open()
                $content = $desiredFile.ReadToEnd()
                $desiredFile.Close()
                $desiredFile.Dispose()

                $replaceCallback = {
                    param(
                        [System.Text.RegularExpressions.Match] $Match
                    )
                    
                    $value = Get-TaskVariable -Name $Match.Groups[1].Value
                    if (!$value)
                    {
                        if ($replaceWithEmptyText) {
                            $value = [string]::Empty
                            Write-Verbose "Variable '$($Match.Groups[1].Value)' not found. Replaced with empty." -Verbose
                        }
                        else {
                            $value = $Match.Value
                            Write-Verbose "Variable '$($Match.Groups[1].Value)' not found. Kept token." -Verbose
                        }

                    }
                    
                    Write-Verbose "Replacing '$($Match.Value)' with '${value}'" -Verbose
                    $value
                }
        
                $content = $regex.Replace($content, $replaceCallback)
                # Re-open the file this time with streamwriter
                $desiredFile = [System.IO.StreamWriter]($matchingEntry).Open()

                # If needed, zero out the file -- in case the new file is shorter than the old one
                $desiredFile.BaseStream.SetLength(0)

                # Insert the $text to the file and close
                $desiredFile.Write($content -join "`r`n")
                $desiredFile.Flush()
                $desiredFile.Close()
            }

            # Write the changes and close the zip file
            $fileZip.Dispose()
        }
        finally
        {
            $fileZip.Dispose()
        }
    }
}
catch [Exception] {
    Write-Error ($_.Exception.ToString())
    Write-Host "##vso[task.logissue type=error;]$Error[0]"
    Write-Host "##vso[task.complete result=Failed;]Unintentional failure. Error encountered. Defaulting to always fail." 
} 
finally {
	Trace-VstsLeavingInvocation $MyInvocation
}