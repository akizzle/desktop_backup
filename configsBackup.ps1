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
    appdata      = "$env:USERPROFILE\AppData\"
    wowinterface    = "D:\Program Files (x86)\World of Warcraft\_retail_\Interface"
    wowWTF          = "D:\Program Files (x86)\World of Warcraft\_retail_\WTF"
    documents       = "$env:USERPROFILE\Documents"
    pictures        = "$env:USERPROFILE\Pictures"
    downloads       = "$env:USERPROFILE\Downloads"
    desktop         = "$env:USERPROFILE\Desktop"
} 

$drives = ("C:\", "D:\")

# specify backup dir
$backupDir = "D:\Config Backups"
# set backup date for files
$fileDate = Get-Date -Format "MM.dd.yyyy_HH.mm.ss"
# set 7zip executable
$7z = "$env:ProgramFiles\7-zip\7z.exe"
# set shadow copy mount location
$scDir = "C:\ShadowCopy"
# how long you want to keep backups for
$retDate = (Get-Date).AddDays(-14)

try{
    if($action -eq "backup"){
        if($choco -eq "yes"){
            # choco package list backup
            # credit for export-chocolatey.ps1 goes to https://gist.github.com/alimbada/449ddf65b4ef9752eff3
            .\export-chocolatey.ps1 > "$backupDir\packages$fileDate.config"
        }
        if(Test-Path -path $7z){
            # creates SC, mounts to the $scDir directory, performs backup then cleans up the SC & $scDir folder
            Invoke-CimMethod -MethodName Create -ClassName Win32_ShadowCopy -Arguments @{Volume= "C:\\"}
            $sc = Get-CimInstance -ClassName Win32_ShadowCopy | Select-Object -Last 1
            Invoke-Expression -Command "cmd /c mklink /d $scDir $($sc.DeviceObject)\" | Out-Null
            $appDirs.GetEnumerator() | ForEach-Object{
                # deletes any backup zip older than 14 days.
                Get-ChildItem -path "$backupDir\$($_.Key)*" | Where-Object {$_.LastWriteTime -lt $retDate} | Remove-Item -Force -ErrorAction SilentlyContinue
                # checks if path is present, if so perform backup
                if(Test-Path $_.Value){
                    & $7z a "$backupDir\$($_.Key)_$fileDate.zip" $_.Value.Replace('C:\', "$scDir\")
                }
            }
            vssadmin delete shadows /shadow="$($sc.ID)" /quiet
            Remove-Item $scDir
        }
    }elseif($action -eq "restore"){
        if($choco -eq "yes"){
            # install choco & 7zip
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            choco install 7zip
            # retrieves latest package backup & install
            $chocoLatest = Get-ChildItem -path "$backupDir\packages*" | Sort-Object LastWriteTime | Select-Object -last 1
            choco install $chocoLatest -y
        }
        $appDirs.GetEnumerator() | ForEach-Object{
            if(Test-Path $_.Value){
                # select latest backup .zip
                $restoreZip = Get-ChildItem -path "$backupDir\$($_.Key)*" | Sort-Object LastWriteTime | Select-Object -last 1
                # pulls processes running
                $procs = Get-Process -Name "$($_.Key)*"
                # if processes exist, kill for restore & start application
                if($procs){
                    $startApp = $procs.Path | Select-Object -First 1
                    foreach ($proc in $procs){
                        $proc.kill()
                        # gives tasks enough time to kill before restore
                        Start-Sleep -Milliseconds 500
                    }
                    # extract archive to original directory, will overwrite existing files.
                    & $7z x $restorezip -o"$($_.Value)" -aoa
                    & $startApp
                }else{
                    # extract archive to original directory, will overwrite existing files.
                    & $7z x $restorezip -o"$($_.Value)" -aoa
                }
            }
        }
    }else{
        Write-Output 'No action taken.'
    }
}catch{
    Write-Error $_
    End
}
