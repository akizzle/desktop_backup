<#
MUST INSTALL 7zip prior to backing up & restoring. If choco param is present 7zip will be installed during the restore process.
Run powershell in elevated mode.
.EXAMPLE
performs backup without backing up choco package list
configBackups.ps1 -action backup
.EXAMPLE
performs restore without installing chocolatey and packages.
configBackups.ps1 -action restore
.EXAMPLE
performs backup and exports choco package list
configBackups.ps1 -action backup -choco yes
.EXAMPLE
performs restore and installs chocolatey along with all packages in the .config
configBackups.ps1 -action restore -choco yes
#>
[CmdletBinding()]
param
(
   [Parameter(Mandatory=$true)]
   [string]
   $action,

   [Parameter()]
   [string]
   $choco
)

# specify applications & directories that you want backed up or restored.
$appDirs = @{
    streamdeck      = "$env:USERPROFILE\AppData\Roaming\Elgato\StreamDeck"
    wowinterface    = "D:\Program Files (x86)\World of Warcraft\_retail_\Interface"
    wowWTF          = "D:\Program Files (x86)\World of Warcraft\_retail_\WTF"
    icue            = "$env:USERPROFILE\AppData\Roaming\Corsair\CUE Backup"
    lghub           = "$env:USERPROFILE\Appdata\Local\LGHUB"
    documents       = "$env:USERPROFILE\Documents"
    pictures        = "$env:USERPROFILE\Pictures"
    downloads       = "$env:USERPROFILE\Downloads"
    desktop         = "$env:USERPROFILE\Desktop"
} 

# specify backup dir
$backupDir = "D:\Config Backups"
# set backup date for files
$fileDate = Get-Date -Format "MM.dd.yyyy_HH.mm.ss"
# set 7zip executable
$7z = "$env:ProgramFiles\7-zip\7z.exe"

function Backup-Process {
    param (
        $appName,
        $backupDir,
        $appDir,
        $action,
        $sevenZip
    )
    $procs = Get-Process -Name "$appName*"
    # set 7zip executable
    if($procs){
        $startApp = $procs.Path | Select-Object -First 1
        $procs | Stop-Process -Force
        if($action -eq "backup"){
            & $7z a "$backupDir\$($appName)_$fileDate.zip" $appDir
            & $startApp
        }elseif($action -eq "restore"){
            $restoreZip = Get-ChildItem -path "$backupDir\$appName*" | Sort-Object LastWriteTime | Select-Object -last 1
            & $7z e $restorezip -o$appDir
            & $startApp
        }else{
            Write-Output 'No action taken.'
        }
    }else{
        if($action -eq "backup"){
            & $7z a "$backupDir\$($appName)_$fileDate.zip" $appDir
        }elseif($action -eq "restore"){
            & $7z e $restorezip -o$appDir
        }else{
            Write-Output "No action taken."
        }
    }
}

try{
    if($action -eq "backup"){
        if($choco -eq "yes"){
            # choco package list backup
            # credit for export-chocolatey.ps1 goes to https://gist.github.com/alimbada/449ddf65b4ef9752eff3
            .\export-chocolatey.ps1 > "$backupDir\packages$fileDate.config"
        }
        if(Test-Path -path $7z){
            $appDirs.GetEnumerator() | ForEach-Object{
                # deletes any backup zip older than 14 days.
                Get-ChildItem -path "$backupDir\$($_.Key)*" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-14)} | Remove-Item -Force -ErrorAction SilentlyContinue
                # checks if path is present, if so perform backup
                if(Test-Path $_.Value){
                    Backup-Process -appName $_.Key -backupDir $backupDir -appDir $_.Value -action $action -sevenZip $7z
                }
            }
        }
    }elseif($action -eq "restore"){
        if($choco -eq "yes"){
            # install choco
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            # install 7zip to perform extraction ahead.
            choco install 7zip
            # retrieves latest package backup
            $chocoLatest = Get-ChildItem -path "$backupDir\packages*" | Sort-Object LastWriteTime | Select-Object -last 1
            # install packages
            choco install $chocoLatest -y
        }
        $appDirs.GetEnumerator() | ForEach-Object{
            # select latest backup .zip
            if(Test-Path $_.Value){
                Backup-Process -appName $_.Key -backupDir $backupDir -appDir $_.Value -action $action -sevenZip $7z
            }
        }
    }else{
        Write-Output 'No action taken.'
    }
}catch{
    Write-Error $_
    End
}

