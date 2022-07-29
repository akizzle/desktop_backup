<#
MUST INSTALL 7zip prior to backing up, restoring will install 7zip prior to extraction.
Run powershell in elevated mode.
.EXAMPLE
Runs script and performs disable/delete
configBackups.ps1 -action backup
.EXAMPLE
Performs restore
configBackups.ps1 -action restore
#>
[CmdletBinding()]
param
(
   [Parameter(Mandatory=$true)]
   [string]
   $action
)

# specify applications & directories that you want backed up or restored.
$appDirs = @{
    streamDeck      = "$env:USERPROFILE\AppData\Roaming\Elgato\StreamDeck\Backup"
    wowInterface    = "D:\Program Files (x86)\World of Warcraft\_retail_\Interface"
    wowWTF          = "D:\Program Files (x86)\World of Warcraft\_retail_\WTF"
    iCUE            = "$env:USERPROFILE\AppData\Roaming\Corsair\CUE Backup"
    lgHub           = "$env:USERPROFILE\Appdata\Local\LGHUB"
    #documents       = "$env:USERPROFILE\Documents"
    #pictures        = "$env:USERPROFILE\Pictures"
    #downloads       = "$env:USERPROFILE\Downloads"
    #desktop         = "$env:USERPROFILE\Desktop"
} 

# specify backup dir
$backupDir = "D:\Config Backups"
# set backup date for files
$fileDate = Get-Date -Format "MM.dd.yyyy_HH.mm.ss"
# set 7zip executable
$7z = "$env:ProgramFiles\7-zip\7z.exe"

try{
    if($action -eq 'backup'){
        # choco package list backup
        .export-chocolatey.ps1 > "$backupDir\packages$fileDate.config"
        if(Test-Path -path $7z){
            $appDirs.GetEnumerator() | ForEach-Object{
                # deletes any backup zip older than 14 days.
                Get-ChildItem -path "$backupDir\$($_.Key)*" | Sort-object -Property LastWriteTime | Where-Object {LastWriteTime -gt (Get-Date).AddDays(-14)} | Remove-Item -Force
                # checks if path is present, if so perform backup
                if(Test-Path $_.Value){
                    if($_.Key -eq "lgHub"){
                        # kills lghub processes due to file in use
                        Get-Process | Where-Object {$_.Name -like 'lghub*'} | Stop-Process -Force
                    }
                # archives targetted directories
                & $7z a "$backupDir\$($_.Key)_$fileDate.zip" $_.Value
                }
            }
        }
    }elseif($action -eq 'restore'){
        # install choco
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        # install 7zip to perform extraction ahead.
        choco install 7zip
        # retrieves latest package backup
        $chocoLatest = Get-ChildItem -path "$backupDir\packages*" | Sort-Object -Property LastWriteTime | Select-Object -last 1
        # install packages
        choco install $chocoLatest -y
        $appDirs.GetEnumerator() | ForEach-Object{
            #place backup items 
            $restoreZip = Get-ChildItem -path "$backupDir\$($_.Key)*" | Sort-Object -Property LastWriteTime | Select-Object -last 1
            #extracts zip in original locations
            & $7z e $restorezip -o$_.Value
        }
    }else{
        Write-Output 'No action taken.'
    }
}catch{
    Write-Error $_
    End
}

