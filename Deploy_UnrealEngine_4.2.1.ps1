#=======================================
# 		  UE4 Silent Installer
#=======================================
# Author: Alex Porter
# This was originally in batch however
# to make it work better in SCCM
# PowerShell was a much better choice
# so I took the original script and
# ported it over into PowerShell
#=======================================
#===          GitHub Link            ===
#=======================================
# https://github.com/alexporter7
#=======================================
#Notes
#Make temp source folder not have additon ue4.24.1
#copy dat into version folder

#================ Logging Information ================
$Hostname = hostname
$DateInfo = Get-Date -UFormat "%m_%d_%Y %H_%M_%S"; #log the date
$LogFileName = "$($DateInfo)_UnrealDeployment_$Hostname" #name of the log file
$Output = "$(Get-Location)\logs\$($LogFileName).txt"
$CWD = Get-Location
$StartTime = Get-Date

if ((Test-Path "$CWD\logs") -eq $false) {
    New-Item -Path "$CWD\logs" -Type "directory"
}

Function Log($Text) {
    Write-Host "$Text"
    $Text | Out-File $Output -Append
}

#======================================================

$Major = 24
$Minor = 1

$RegistryVersionPath = "HKLM:\Software\SCCMVersion"
$RegistryKeyName = "UELatestDeployed"

Log("Starting Deployment on [$Hostname]")
Log("Major version set to [$Major]")
Log("Minor version set to [$Minor]")

#=== Set Version && Install Location ===
$NetworkSharePath = "\\net.ucf.edu\COS\SCCMDSL\Applications\Local\UE4"
$UEDirectory = "C:\Epic"
$InstallDirectory = "$UEDirectory\UE_4.$Major.$Minor"

#=== Process initial variables ===
$SourcePath = "$NetworkSharePath\4.$Major.$Minor"
$CommonPath = "$NetworkSharePath\common"
$InstallZipFile = "UE_4.$Major"
$ShortcutPath = "$SourcePath\Unreal Engine 4.$Major.$Minor.lnk"
$FirewallRuleName = "UE_4.$Major.$Minor"
$FirewallPath = "$InstallDirectory\Engine\Binaries\Win64\UE4Editor.exe"
$InstallVersionPath = "C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat"
$TempSourcePath = "$UEDirectory\temp_4.$Major.$Minor"

#=== Log all of the variables as they are set ===
Log("Network Share Path set to [$NetworkSharePath]`nInstall Directory set to [$InstallDirectory]`nSource Path set to [$SourcePath]")
Log("Common Path set to [$CommonPath]`nInstall Zip File set to [$InstallZipFile]`nShortcut Path set to [$ShortcutPath]")
Log("Firewall Rule Name set to [$FirewallRuleName]`nFirewall Path set to [$FirewallPath]`nInstall Version Path set to [$InstallVersionPath]")
#================================================

#=== Make sure all install directory paths exists ===
if ((Test-Path "C:\Epic") -eq $false) {
    New-Item -Path "C:\Epic" -Type "directory" | Out-Null
    Log("Created Epic directory in [C:\Epic]")
}

<#if ((Test-Path $InstallDirectory) -eq $false) {
    New-Item -Path $InstallDirectory -Type "directory" | Out-Null
    Log("Completed install directory in [$InstallDirectory]")
}#>

if ((Test-Path "$TempSourcePath") -eq $false) {
    New-Item -Path "$TempSourcePath" -Type "directory" | Out-Null
    Log("Created temporary directory to copy source")
}

if((Test-Path "$UEDirectory\versions") -eq $false) {
    New-Item -Path "$UEDirectory\versions" -Type "directory" | Out-Null
    Log("Created version folder")
}

#=== Check if version folder is hidden ===
if ((Get-Item "$UEDirectory\versions" -Force).Attributes -eq "directory") {

    (Get-Item "$UEDirectory\versions").Attributes = "hidden"
    Log("Directory [$UEDirectory\versions] set to hidden")

} elseif ((Get-Item "$UEDirectory\versions" -Force).Attributes -eq "hidden") {

    Log("Directory [$UEDirectory\versions] found but already set to hidden")

} else {

    Log("Something went wrong with the versions directory")

}

#=== Start copying zip files to temp directory ===
Log("Copying files from [$SourcePath] to [$TempSourcePath]")

Copy-Item -Path $SourcePath -Destination $TempSourcePath -Force -Recurse

Log("Done")
Log("Copying [4.$Major.$Minor.dat] from [$TempSourcePath\4.$Major.$Minor\UE_4.$Major.$Minor.dat] to [$UEDirectory\versions\UE_4.$Major.$Minor.dat]")

Copy-Item -Path "$TempSourcePath\4.$Major.$Minor\UE_4.$Major.$Minor.dat" -Destination "$UEDirectory\versions\UE_4.$Major.$Minor.dat"

Log("Done")
Log("Extracting Unreal Engine files with 7zip")

#Unzip the temp files to the install path
Set-Alias SZ "$CommonPath\7za\7za.exe"
$7zFile = "$TempSourcePath\4.$Major.$Minor\$InstallZipFile.7z.001"
$7zOptions = "-aos"

SZ x $7zOptions $7zFile "-o$UEDirectory"

Log("Done")
Log("Renaming Install Directory")

Rename-Item -Path "$UEDirectory\UE_4.$Major" -NewName "UE_4.$Major.$Minor"

Log("Done")
Log("Changing permission settings on [$UEDirectory]")

Start-Process "cmd" -ArgumentList "/c ICACLS `"C:\Epic`" /Q /grant `"Authenticated Users`":M"

#=== Verify Firewall Rules ===
$LauncherOutRule = Get-NetFirewallRule -DisplayName "UE_LAUNCHER_out"
if ($LauncherOutRule -eq $null) {
    Log("Firewall Rule [UE_LAUNCHER_out] does NOT exist, creating now")
    New-NetFirewallRule -DisplayName "UE_LAUNCHER_out" -Direction Inbound -Program "C:\Program Files (x86)\epic games\launcher\portal\binaries\win64\epicgameslauncher.exe" -Action Allow
} else {
    Log("Firewall Rule [UE_LAUNCHER_out] already exists")
}

$LauncherInRule = Get-NetFirewallRule -DisplayName "UE_LAUNCHER_in"
if ($LauncherInRule -eq $null) {
    Log("Firewall Rule [UE_LAUNCHER_in] does NOT exist, creating now")
    New-NetFirewallRule -DisplayName "UE_LAUNCHER_in" -Direction Inbound -Program "C:\Program Files (x86)\epic games\launcher\portal\binaries\win64\epicgameslauncher.exe" -Action Allow
} else {
    Log("Firewall Rule [UE_LAUNCHER_in] already exists")
}

#=== Install Firewall Rules ===
$UEOutRule = Get-NetFirewallRule -DisplayName "$($FirewallRuleName)_out"
if ($UEOutRule -eq $null) {
    Log("Firewall Rule [$($FirewallRuleName)_out] does NOT exist, creating now")
    New-NetFirewallRule -DisplayName "$($FirewallRuleName)_out" -Direction Inbound -Program "C:\Epic\UE_4.24.1\Engine\Binaries\Win64\UE4Editor.exe" -Action Allow
} else {
    Log("Firewall Rule [$($FirewallRuleName)_out] already exists")
}

$UEInRule = Get-NetFirewallRule -DisplayName "$($FirewallRuleName)_in"
if ($UEInRule -eq $null) {
    Log("Firewall Rule [$($FirewallRuleName)_in] does NOT exist, creating now")
    New-NetFirewallRule -DisplayName "$($FirewallRuleName)_in" -Direction Inbound -Program "C:\Epic\UE_4.24.1\Engine\Binaries\Win64\UE4Editor.exe" -Action Allow
} else {
    Log("Firewall Rule [$($FirewallRuleName)_in] already exists")
}

#=== Install Prerequisites ===

Log("Started [UE4PrereqSetup_x64.exe]")

Start-Process "$InstallDirectory\Engine\Extras\Redist\en-us\UE4PrereqSetup_x64.exe" -ArgumentList "/q"

Log("Completed [UE4PrereqSetup_x64.exe]")
Log("Started [UE4PrereqSetup_x86.exe]")

Start-Process "$InstallDirectory\Engine\Extras\Redist\en-us\UE4PrereqSetup_x86.exe" -ArgumentList "/q"

Log("Started [UE4PrereqSetup_x86.exe]")

#=== Copy Desktop Shortcut ===

Copy-Item -Path $ShortcutPath -Destination "C:\Users\Public\Desktop\Unreal Engine 4.$Major.$Minor.lnk"
Log("Copied Desktop Shortcut to [C:\Users\Public\Desktop\Unreal Engine 4.$Major.$Minor.lnk]")

#=== Construct Launcher InstalledVersions.dat ===
#remove existing
#Build LauncherInstalled.dat

Log("Setting [UE_4.$Major.$Minor.dat] to read only")
Set-ItemProperty -Path "$UEDirectory\versions\UE_4.$Major.$Minor.dat" -Name IsReadOnly -Value $true
Log("Done")

#=== Add File Type Associations ===
Log("Import registry key from [$CommonPath\uProjectAssociation.reg]")

REG IMPORT "$CommonPath\uProjectAssociation.reg"

Log("Registry key imported")
Log("Creating Version registry folder in [$RegistryVersionPath]")

New-Item -Path $RegistryVersionPath
New-ItemProperty -Path $RegistryVersionPath -Name "$RegistryKeyName" -Value "4.$Major.$Minor"

Log("Done, set [$RegistryVersionPath] Item [$RegistryKeyName] to [4.$Major.$Minor]")

#=== Remove Zip Files from Temp Directory ===
if((Test-Path "$TempSourcePath") -eq $true) {

    Log("Temp files found in [$TempSourcePath] deleting now")
    Remove-Item -Path $TempSourcePath -Recurse -Force
    Log("Finished removing temporary files")

} else {

    Log("Temp files not found, skipping delete")

}

$EndTime = Get-Date

Log("Completed in [$(($EndTime - $StartTime).Seconds)] seconds")
Log("============== DONE ==============")

Exit
