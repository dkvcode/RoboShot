#===========================================================================================
# === roboshot.ps1 =========================================================================
#
# author:  Thomas Hiller
# date:    17/03/2010
# version: 0.3
#
# url: https://sourceforge.net/projects/roboshot
# contact: please contact me via the sourceforge project site
#
# script that uses ROBOCOPY.EXE (v026 and above) to make a rsnapshot-like backup
# routine.
# Hardlinking:
# On XP FSUTIL.EXE is used for backups on local NTFS volumes (internal,usb)
# On XP LN.EXE is used for backups on remote NTFS or Samba shares
# On Windows 7 MKLINK is used for backups on local NTFS volumes (internal,usb)
# On Windows 7 LN.EXE is used for backups on remote NTFS or Samba shares
#
# IMPORTANT: See README.TXT file for instructions
#
# needs roboshot.cfg as configuration file
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#===========================================================================================

# make sure $error is cleared
$Error.Clear()
#$erroractionpreference = "SilentlyContinue"
$erroractionpreference = "Stop"
Clear-Host

$cmdparas = $args

function New-Symlink {
<#
.SYNOPSIS
Creates a symbolic link.
#>
param (
[Parameter(Position=0, Mandatory=$true)]
[string] $Link,
[Parameter(Position=1, Mandatory=$true)]
[string] $Target
)
 
Invoke-MKLINK -Link $Link -Target $Target -Symlink
}
 
 
function New-Hardlink {
<#
.SYNOPSIS
Creates a hard link.
#>
param (
[Parameter(Position=0, Mandatory=$true)]
[string] $Link,
[Parameter(Position=1, Mandatory=$true)]
[string] $Target
)
 
Invoke-MKLINK -Link $Link -Target $Target -HardLink
}
 
 
function New-Junction {
<#
.SYNOPSIS
Creates a directory junction.
#>
param (
[Parameter(Position=0, Mandatory=$true)]
[string] $Link,
[Parameter(Position=1, Mandatory=$true)]
[string] $Target
)
 
Invoke-MKLINK -Link $Link -Target $Target -Junction
}
 
 
function Invoke-MKLINK {
<#
.SYNOPSIS
Creates a symbolic link, hard link, or directory junction.
#>
[CmdletBinding(DefaultParameterSetName = "Symlink")]
param (
[Parameter(Position=0, Mandatory=$true)]
[string] $Link,
[Parameter(Position=1, Mandatory=$true)]
[string] $Target,
 
[Parameter(ParameterSetName = "Symlink")]
[switch] $Symlink = $true,
[Parameter(ParameterSetName = "HardLink")]
[switch] $HardLink,
[Parameter(ParameterSetName = "Junction")]
[switch] $Junction
)
$mklinkArg = ""
 <#
# Ensure target exists.
if (-not(Test-Path $Target)) {
throw "Target does not exist.`nTarget: $Target"
}
 
# Ensure link does not exist.
if (Test-Path $Link) {
throw "A file or directory already exists at the link path.`nLink: $Link"
}

$isDirectory = (Get-Item $Target).PSIsContainer

if ($Symlink -and $isDirectory) {
$mkLinkArg = "/D"
}
#>
 
if ($Junction) {
# Ensure we are linking a directory. (Junctions don't work for files.)
if (-not($isDirectory)) {
throw "The target is a file. Junctions cannot be created for files.`nTarget: $Target"
}
 
$mklinkArg = "/J"
}
 
if ($HardLink) {
<#
# Ensure we are linking a file. (Hard links don't work for directories.)
if ($isDirectory) {
throw "The target is a directory. Hard links cannot be created for directories.`nTarget: $Target"
}
#>
$mkLinkArg = "/H"
}
 
# Capture the MKLINK output so we can return it properly.
# Includes a redirect of STDERR to STDOUT so we can capture it as well.
$output = cmd /c mklink $mkLinkArg `"$Link`" `"$Target`" 2>&1
 
if ($lastExitCode -ne 0) {
throw "MKLINK failed. Exit code: $lastExitCode`n$output"
}
else {
Write-Output $output
}
}

# ===============================================
# === some useful functions =====================
# ===============================================
function Fatal-End{
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	$msg = @"
======================================================================
$timestamp

RoboShot encountered an ERROR
RoboShot is aborting ...
======================================================================
"@
	Write-Host $msg
	if ($nologfile -eq $false){
	Out-File -filePath $logfilemain -InputObject $msg -Append}
	exit
}

function Check-Tools{
	# we need the buildnumber to determine the windows version
	# 2600 and above XP
	# 6000 and above Vista
	# 7600 Windows 7
	$build = (Get-WmiObject Win32_OperatingSystem).BuildNumber
	# we also need the %PATH%
	$envpath = Get-Content ENV:PATH
	$envpath_count = [regex]::matches($envpath,";").count
	# resort all paths in %PATH%
	$newpath = @()
	for($i=0; $i -le $envpath_count; $i++){
		$newpath += $envpath.Split(";")[$i]
	}
	if($build -ge 2600 -and $build -lt 6000){
		# we're on XP so fsutil.exe can be used
		# for local backups
		# ln.exe as fallback if somehow fsutil is missing
		# for remote ones we need ln.exe
		# first check for the "snapshot_roottype"
		if($destpathtype -eq "local"){
			# now check for fsutil.exe
			$isfsutil = $false
			foreach ($partpath in $newpath){
				$fsutiltest = Join-Path -Path $partpath -ChildPath "fsutil.exe"
				if(Test-Path $fsutiltest -pathtype leaf){
					$isfsutil = $true
				}
			}
			if($isfsutil -eq $true){
				$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
				$msg = @"
======================================================================
$timestamp

The snapshot_root is a local NTFS volume.

Found fsutil.exe

Everything is ready for backup.
======================================================================
"@
				Write-Host $msg
				Out-File -filePath $logfilemain -InputObject $msg -Append
				Set-Variable -Name usefsutil -Value 1 -Option ReadOnly -Scope Global -Force
			}
			elseif($isfsutil -eq $false){
				$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
				$msg = @"
======================================================================
$timestamp

The snapshot_root is a local NTFS volume.

Didn't Found fsutil.exe

RoboShot tries to find ln.exe in your %PATH%
======================================================================
"@
				Write-Host $msg
				Out-File -filePath $logfilemain -InputObject $msg -Append
				# now check for ln.exe
				$isln = $false
				foreach ($partpath in $newpath){
					$lntest = Join-Path -Path $partpath -ChildPath "ln.exe"
					if(Test-Path $lntest -pathtype leaf){
						$isln = $true
					}
				}
				if($isln -eq $true){
					$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
					$msg = @"
======================================================================
$timestamp

The snapshot_root is a local NTFS volume.

Found ln.exe

Everything is ready for backup.
======================================================================
"@
					Write-Host $msg
					Out-File -filePath $logfilemain -InputObject $msg -Append
					Set-Variable -Name useln -Value 1 -Option ReadOnly -Scope Global -Force
			}
				elseif($isln -eq $false){
					$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
					$msg = @"
======================================================================
$timestamp

The snapshot_root is a local NTFS volume.

Didn't Found ln.exe
======================================================================
"@
					Write-Host $msg
					Out-File -filePath $logfilemain -InputObject $msg -Append
					Fatal-End
				}
			}
		}
		elseif($destpathtype -eq "remote"){
			# now check for ln.exe
			$isln = $false
			foreach ($partpath in $newpath){
				$lntest = Join-Path -Path $partpath -ChildPath "ln.exe"
				if(Test-Path $lntest -pathtype leaf){
					$isln = $true
				}
			}
			if($isln -eq $true){
				$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
				$msg = @"
======================================================================
$timestamp

The snapshot_root is a remote NTFS volume or Samba-Share.

Found ln.exe

Everything is ready for backup.
======================================================================
"@
				Write-Host $msg
				Out-File -filePath $logfilemain -InputObject $msg -Append
				Set-Variable -Name useln -Value 1 -Option ReadOnly -Scope Global -Force
			}
			elseif($isln -eq $false){
				$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
				$msg = @"
======================================================================
$timestamp

The snapshot_root is a remote NTFS volume or Samba-Share.

Didn't Found ln.exe
======================================================================
"@
				Write-Host $msg
				Out-File -filePath $logfilemain -InputObject $msg -Append
				Fatal-End
			}
		}
	}
	elseif($build -ge 6000){
		# we're on Vista or Windows 7 so we use mklink	
		# for local backups
		# mklink is a build-in "cmd.exe" routine on Windows 7
		# not tested on Vista
		# for remote backups we need ln.exe
		# first check for the "snapshot_roottype"
		if($destpathtype -eq "local"){
			$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
			$msg = @"
======================================================================
$timestamp

The snapshot_root is a local NTFS volume.

Using mklink bulit-in "cmd.exe" routine

Everything is ready for backup.
======================================================================
"@
			Write-Host $msg
			Out-File -filePath $logfilemain -InputObject $msg -Append
			Set-Variable -Name usemklink -Value 1 -Option ReadOnly -Scope Global -Force
		}
		elseif($destpathtype -eq "remote"){
			# now check for ln.exe
			$isln = $false
			foreach ($partpath in $newpath){
				$lntest = Join-Path -Path $partpath -ChildPath "ln.exe"
				if(Test-Path $lntest -pathtype leaf){
					$isln = $true
				}
			}
			if($isln -eq $true){
				$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
				$msg = @"
======================================================================
$timestamp

The snapshot_root is a remote NTFS volume or Samba-Share.

Found ln.exe

Everything is ready for backup.
======================================================================
"@
				Write-Host $msg
				Out-File -filePath $logfilemain -InputObject $msg -Append
				Set-Variable -Name useln -Value 1 -Option ReadOnly -Scope Global -Force
			}
			elseif($isln -eq $false){
				$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
				$msg = @"
======================================================================
$timestamp

The snapshot_root is a remote NTFS volume or Samba-Share.

Didn't Found ln.exe
======================================================================
"@
				Write-Host $msg
				Out-File -filePath $logfilemain -InputObject $msg -Append
				Fatal-End
			}
		}
	}
}

function Get-Cmdlineparameters($cmdparas){
# if the first parameter is -c we assume an alternative
# config file
if ($cmdparas[0] -like "-c"){
	# if it is -c then the last(third) should be the interval
	# if there is nothing...abort
	if ($cmdparas.Count -lt 3){
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

Looks like you've forgot to give an interval after your config file
======================================================================
"@
		Write-Host $msg
		Fatal-End
	}
	# the second parameter should be the path to the config file
	# in "" marks (in case of space characters)
	$testcfgfile = $cmdparas[1]
	if (Test-Path $testcfgfile){
		Set-Variable -Name robocfg -Value $testcfgfile -Option ReadOnly -Scope Global -Force	
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

Your config file

$robocfg

is available
======================================================================
"@
		Write-Host $msg
	}
	else{
		# if the config file from the second parameter doesn't exist
		# we fall back to the default one roboshot.cfg
		$tmpfile = Join-Path $PWD "roboshot.cfg"		
		Set-Variable -Name robocfg -Value $tmpfile -Option ReadOnly -Scope Global -Force
		Remove-Variable tmpfile
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

Your config file

$testcfgfile

is NOT available.

Using default location in:

$PWD
======================================================================
"@
		Write-Host $msg
	}
	Remove-Variable testcfgfile
	Set-Variable -Name currentinterval -Value $cmdparas[2] -Option ReadOnly -Scope Global -Force
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	$msg = @"
======================================================================
$timestamp

Roboshot uses $currentinterval as interval
======================================================================
"@
	Write-Host $msg
	Check-Robocfg $robocfg
}
elseif ( ($cmdparas.Count -eq 0) -and ($cmdparas.Length -eq 0) -or ($cmdparas -like "help") -or ($cmdparas -like "/?")`
-or ($cmdparas -like "-h") ){
	# no cmd parameters given --> show help
	# help, /? and -h --> show help
	Show-Help
}
else{
	# only one argument given...we assume it's the interval
	# using default config file roboshot.cfg
	Set-Variable -Name robocfg -Value (Join-Path $PWD "roboshot.cfg") -Option ReadOnly -Scope Global -Force
	Set-Variable -Name currentinterval -Value $cmdparas[0] -Option ReadOnly -Scope Global -Force
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	$msg = @"
======================================================================
$timestamp

Roboshot uses $currentinterval as interval

Roboshot uses default config file "roboshot.cfg" in 

$PWD
======================================================================
"@
	Write-Host $msg
	Check-Robocfg $robocfg
	}
}

function Show-Help{
$msg = @"
======================================================================
You either started Roboshot without any parameter or by invoking
'help' or '/?' or '-h'
This shows you this short help text.

For detailed information refer to the README.TXT which came together
with this script.

+++++++++++++++++++++++++++++++++++++++

You can run Roboshot like:

.\roboshot.ps1 interval

where 'interval' is one interval specified in the config file
roboshot.cfg

You can also give an alternative config file with

.\roboshot.ps1 -c "D:\path\to\config file" interval

where you put the complete path to the alternative config file in
""-marks (in case of space characters)
'interval' is of course again one interval specified in your
alternative config file

+++++++++++++++++++++++++++++++++++++++

Roboshot comes without ANY WARRANTY and AS IS. This is an ALPHA
release so be careful when using it and don't blame me if you
loose your data.

RoboShot by Thomas Hiller
Version 0.2
16/03/2010
======================================================================
"@
Write-Host $msg
exit
}

function Check-Robocfg($robocfg){
	Set-Variable -Name nologfile -Value $false -Scope Global
	# now check if the config file exists
	if (Test-Path $robocfg){
		# if it exists proceed
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

roboshot.cfg is available
======================================================================
"@
		Write-Host $msg
		#Out-File -FilePath $logfilemain -InputObject $msg -Append
	}
	else{
		# if not abort
		Set-Variable -Name nologfile -Value $true
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

roboshot.cfg is not available in

$PWD

Check!
======================================================================
"@
		Write-Host $msg
		#Out-File -FilePath $logfilemain -InputObject $msg -Append
		Fatal-End
	}
	Set-Variable -Name cfgfile -Value $robocfg -Option ReadOnly -Scope Global -Force
}

function Get-Logname ([string]$cfgfile){
	Get-Content $cfgfile | foreach-object { if ($_.split("=")[0] -eq "logfile") {$dummy = $_.split("=")[1]} }
	if ($dummy -is [object]){}
	else{
		$dummy = Join-Path $tmp "roboshot.log"
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

You gave no log-file in roboshot.cfg

RoboShot uses default log-file:

$dummy
======================================================================
"@
		Write-Host $msg
		Out-File -FilePath $dummy -InputObject $msg -Append
		}
	Set-Variable -Name logfilemain -Value $dummy -Option ReadOnly -Scope Global -Force
	Remove-Variable dummy
	
}

function Get-Interval ([string]$cfgfile){
	$dummy = @()
	Get-Content $cfgfile | foreach-object {
		if ($_.split("=")[0] -eq "interval") {
			$dummy1 = $_.split("=")[1]
			$dummy += [string]$dummy1.split(":")[0];
			$dummy += [int]$dummy1.split(":")[1]
		} }	
	
	if ($dummy.Count -le 1){
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

Something is wrong with your intervals in the config-file

Make sure it looks like:

interval=daily:7
======================================================================
"@
		Write-Host $msg
		Out-File -FilePath $logfilemain -InputObject $msg -Append		
		Fatal-End
	}
	else {
		Foreach ($dummy1 in $dummy){
			if ($dummy1 -le 0){
				$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
				$msg = @"
======================================================================
$timestamp

Something is wrong with your intervals in the config-file

Make sure it looks like:

interval=daily:7
======================================================================
"@
				Write-Host $msg
				Out-File -FilePath $logfilemain -InputObject $msg -Append		
				Fatal-End
			}
		}
	}
	Set-Variable -Name interval -Value $dummy -Option ReadOnly -Scope Global -Force
	Remove-Variable dummy, dummy1
}

function Get-SrcPaths ([string]$cfgfile){
	$dummy = @()
	Get-Content $cfgfile | foreach-object { if ($_.split("=")[0] -eq "backup") {$dummy += [string]$_.split("=")[1]} }
	Set-Variable -Name src -Value $dummy -Option ReadOnly -Scope Global -Force
	Remove-Variable dummy
	if ($src.Count -eq 0 -or $src.SyncRoot[0].Length -eq 0){
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

Something is wrong with your source paths in the config-file
Make sure to give a source path like:

---------------------------------
backup=C:\drive\to backup
---------------------------------
======================================================================
"@
	Write-Host $msg
	Out-File -filePath $logfilemain -InputObject $msg -Append
	Fatal-End
	}
	else{
		foreach ($Source in $src){
			if (Test-Path -Path $Source){}else{
				$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
				$msg = @"
======================================================================
$timestamp

Something is wrong with your source paths in the config-file
The backup folder:
$Source
does not exist
======================================================================
"@
				Write-Host $msg
				Out-File -filePath $logfilemain -InputObject $msg -Append				
				Fatal-End
			}
		}
	}
}

function Get-DestPaths ([string]$cfgfile){
	$dummy = @()
	Get-Content $cfgfile | foreach-object { if ($_.split("=")[0] -eq "snapshot_root") {$dummy += [string]$_.split("=")[1]} }
	Set-Variable -Name dest -Value $dummy -Option ReadOnly -Scope Global -Force
	Remove-Variable dummy
	if ($dest.Length -eq 0){
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	$msg = @"
======================================================================
$timestamp

Something is wrong with your snapshot_root path in the config-file
Make sure to give the snapshot_root path like:

---------------------------------
snapshot_root=X:\drive\where\backup\is
---------------------------------
======================================================================
"@
	Write-Host $msg
	Out-File -filePath $logfilemain -InputObject $msg -Append
	Fatal-End
	}
	else{
		$destdrive = Split-Path $dest -Qualifier
		if(Test-Path -Path $destdrive){
			Create-snapshotRoot $dest
		}
		else{
			$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
			$msg = @"
======================================================================
$timestamp

Backup Drive $destdrive is not reachable
======================================================================
"@
			Write-Host $msg
			Out-File -filePath $logfilemain -InputObject $msg -Append
			Fatal-End			
		}
	}
}

function Get-DestPathType([string]$cfgfile){
	Get-Content $cfgfile | foreach-object { if ($_.split("=")[0] -eq "snapshot_roottype") {$dummy = [string]$_.split("=")[1]} }
	if($dummy -ne "local" -and $dummy -ne "remote"){
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

The "snapshot_roottype" has to be "local" or "remote"
======================================================================
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
		Fatal-End			
	}
	else{
		Set-Variable -Name destpathtype -Value $dummy -Option ReadOnly -Scope Global -Force
		Remove-Variable dummy
	}
}

function Get-ExclPaths ([string]$cfgfile){
	$dummy = @()
	Get-Content $cfgfile | foreach-object { if ($_.split("=")[0] -eq "exclude_path") {$dummy += [string]$_.split("=")[1]} }
	Set-Variable -Name exclpaths -Value $dummy -Option ReadOnly -Scope Global -Force
	Remove-Variable dummy
}

function Get-ExclFiles ([string]$cfgfile){
	$dummy = @()
	Get-Content $cfgfile | foreach-object { if ($_.split("=")[0] -eq "exclude_files") {$dummy += [string]$_.split("=")[1]} }	
	Set-Variable -Name exclfiles -Value $dummy -Option ReadOnly -Scope Global -Force
	Remove-Variable dummy
}

function Create-snapshotRoot($dest){
	# check if destination path exists
	# if not create it
	$destexist = Test-Path $dest -pathType Container
	if ($destexist -eq $True){
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

Backup destination $dest exists
======================================================================
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
	}
	else{
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

Backup destination $dest does not exist
Creating backup destination $dest ...
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
		$destdrive = Split-Path $dest -Qualifier
		$destpath = Split-Path $dest -NoQualifier
		New-Item -path $destdrive  -name $destpath -type directory
		Remove-Variable -Name destdrive,destpath
		if (Test-Path $dest){
			$msg = @"
		
done!
======================================================================
"@
			Write-Host $msg
			Out-File -filePath $logfilemain -InputObject $msg -Append
		}
		else{
			Fatal-End
			}
	}
}

function rotate-lowestsnapshots ($currentinterval, $dest, $interval){
	#$interval_num, $interval_max, $prev_interval, $prev_interval_max = get-Intervaldata $currentinterval $interval
	# remove oldest directory
	$oldestdir = "$dest\$currentinterval.$interval_max"
	if ( (Test-Path $oldestdir) -and ($interval_max -gt 0) ){
		Remove-Item $oldestdir -Recurse		
		$msg = @"
RoboShot removed folder $oldestdir
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
	}
	# rotate the middle ones
	if ($interval_max -gt 0){
		for ($i=($interval_max-1); $i -ge 0; $i--){
			if (Test-Path "$dest\$currentinterval.$i" ){
				$newext = $i+1
				Rename-Item "$dest\$currentinterval.$i" "$dest\$currentinterval.$newext"
				$msg = @"
RoboShot moved folder $dest\$currentinterval.$i to $dest\$currentinterval.$newext
"@
				Write-Host $msg
				Out-File -filePath $logfilemain -InputObject $msg -Append
			}
		}
	}
}

function backup-lowestinterval ($currentinterval, $dest, $interval, $interval_num, $interval_max, $prev_interval, $prev_interval_max){
	# if there is some data -> interval backup
	# if $testpath exist we know what to do
	$testpath = Join-Path $dest "$currentinterval.1"
	if (Test-Path $testpath){
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

RoboShot starts backup with interval $currentinterval
======================================================================
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
		Make-intervalbackup $interval $src $dest $exclpaths $exclfiles $currentinterval
	}
	# if not -> first backup
	else{
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

RoboShot starts the first backup of interval $currentinterval
======================================================================
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
		Make-firstbackup $interval $src $dest $exclpaths $exclfiles $currentinterval
	}
}

function rotate-higherinterval ($currentinterval, $dest, $interval, $interval_num, $interval_max, $prev_interval, $prev_interval_max){
	#$interval_num, $interval_max, $prev_interval, $prev_interval_max = get-Intervaldata $currentinterval $interval
	# remove oldest directory
	$oldestdir = Join-Path $dest "$currentinterval.$interval_max"	
	if ( (Test-Path $oldestdir) -and ($interval_max -gt 0) ){
		Remove-Item $oldestdir -Recurse
		$msg = @"
RoboShot removed folder $oldestdir
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
	}
	# rotate the middle ones
	if ($interval_max -gt 0){
		for ($i=($interval_max-1); $i -ge 0; $i--){
			if (Test-Path "$dest\$currentinterval.$i" ){
				$newext = $i+1
				Rename-Item "$dest\$currentinterval.$i" "$dest\$currentinterval.$newext"
				$msg = @"
RoboShot moved $dest\$currentinterval.$i to $dest\$currentinterval.$newext
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
			}
		}
	}
	#
	$oldestprev_dir = "$dest\$prev_interval.$prev_interval_max"
	if (Test-Path $oldestprev_dir){
		Rename-Item $oldestprev_dir "$dest\$currentinterval.0"
		$msg = @"
RoboShot moved folder $oldestprev_dir to $dest\$currentinterval.0
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
	}
	else{
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

RoboShot was started with interval $currentinterval

$oldestprev_dir not present (yet), nothing to copy
======================================================================
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
	}
}

function get-Intervaldata ($currentinterval, $interval){
	$totalintervalsum = $interval.Count / 2
	$intervalcfgname = @()
	$intervalcfgnr = @()
	for ($x=1; $x -le $totalintervalsum; $x++){
		$intervalcfgname+=$interval[$x*2-2]
		$intervalcfgnr+=$interval[$x*2-1]
	}
	$i = 0
	ForEach ($iref in $intervalcfgname){
		if ($iref -match $currentinterval){
		$tmp_interval_num = $i
		$tmp_interval_max = $intervalcfgnr[$i]-1
		break
		}	
		$tmp_prev_interval = $iref
		$tmp_prev_interval_max = $intervalcfgnr[$i]-1	
		$i+=1
	}
	# check if the submitted interval is existent in the config
	# file...if not abort
	if($tmp_interval_num -is [object]){
	}
	else{
		$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
		$msg = @"
======================================================================
$timestamp

Given Interval $currentinterval doesn't exist in your config file!

Make sure it looks like:

interval=daily:7
======================================================================
"@
		Write-Host $msg
		Out-File -filePath $logfilemain -InputObject $msg -Append
		Fatal-End
	}
	Set-Variable -Name interval_num -Value $tmp_interval_num -Option ReadOnly -Scope Global -Force
	Set-Variable -Name interval_max -Value $tmp_interval_max -Option ReadOnly -Scope Global -Force
	if ($tmp_prev_interval -is [object]){
		Set-Variable -Name prev_interval -Value $tmp_prev_interval -Option ReadOnly -Scope Global -Force
		Set-Variable -Name prev_interval_max -Value $tmp_prev_interval_max -Option ReadOnly -Scope Global -Force
		Remove-Variable -Name tmp_prev_interval,tmp_prev_interval_max
	}
	else{
		Remove-Variable -Name tmp_interval_num,tmp_interval_max
		}	
}

function Make-firstbackup ($interval, $src, $dest, $exclpaths, $exclfiles, $currentinterval){
	# keep it simple...no error checks yet...todo
	$intervalroot = Join-Path -Path $dest -ChildPath $currentinterval".0"
	New-Item $intervalroot -type directory
	Foreach ($Source in $src){
		$srcdest = Split-Path $Source -noQualifier
		$srcdrive = Split-Path $Source -Qualifier
		$srcdest = Join-Path $srcdrive[0] $srcdest
		#$intervaldest = Join-Path -Path $intervalroot -ChildPath $srcdest
		$intervaldest = $intervalroot
		robocopy.exe $Source $intervaldest /XD $exclpaths /XF $exclfiles /XJ /NDL /NFL /E /R:2 /W:1 >> $logfilemain
		Clear-Variable intervaldest
	}
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	$msg = @"
======================================================================
$timestamp

RoboShot finished the first backup of interval $currentinterval
======================================================================
"@
	Write-Host $msg
	Out-File -filePath $logfilemain -InputObject $msg -Append
}

function Make-intervalbackup ($interval, $src, $dest, $exclpaths, $exclfiles, $currentinterval){
	# temp files needed
	# normal use
	$logfiletmpfiles = Join-Path $tmp "roboshot_tmpfiles.log"
	$logfilehardlinks = Join-Path $tmp "roboshot_hardlinks.log"
	# if you want to debug uncomment this
	# see line 755
	#$logfiletmpfiles = Join-Path $PWD "roboshot_tmpfiles.log"
	#$logfilehardlinks = Join-Path $PWD "roboshot_hardlinks.log"
	
	#  1.) --- create directories but don't copy anything yet ---
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	$msg = @"
======================================================================
$timestamp

1.) RoboShot uses Robocopy to first create all directories.
	No files are copied so far.
======================================================================
"@
	Write-Host $msg
	Out-File -filePath $logfilemain -InputObject $msg -Append
	$intervalroot = Join-Path -Path $dest -ChildPath $currentinterval".0"
	New-Item $intervalroot -type directory
	Foreach ($Source in $src){
		$srcdest = Split-Path $Source -noQualifier
		$srcdrive = Split-Path $Source -Qualifier
		$srcdest = Join-Path $srcdrive[0] $srcdest
		#$intervaldest = Join-Path -Path $intervalroot -ChildPath $srcdest
		$intervaldest = $intervalroot
		#Write-Host "SRC: " $Source "DST: " $intervaldest
		robocopy.exe $Source $intervaldest /XD $exclpaths /XJ /NDL /NFL /E /R:2 /W:1 /XF "*" >> $logfilemain 
		Clear-Variable intervaldest
	}
	# 2.) --- hardlink the files that are still existent ---
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	$msg = @"
======================================================================
$timestamp

2.) RoboShot uses Robocopy to make a list of all files to check which
	ones have changed
======================================================================
"@
	Write-Host $msg
	Out-File -filePath $logfilemain -InputObject $msg -Append
	# first make a list of the files
	Foreach ($Source in $src){
		$srcdest = Split-Path $Source -noQualifier
		$srcdrive = Split-Path $Source -Qualifier
		$srcdest = Join-Path $srcdrive[0] $srcdest
		#$linkdest = Join-Path -Path $dest -ChildPath $currentinterval".1\$srcdest"
		$linkdest = Join-Path -Path $dest -ChildPath $currentinterval".1"
		robocopy.exe $Source $linkdest /XD $exclpaths /XF $exclfiles /XJ /NDL /E /NOCOPY /NS /V /FFT /R:2 /W:1 >> $logfiletmpfiles
		Clear-Variable linkdest
	}
	# let's wait a bit so that the tmp file exists
	Start-Sleep -m 500
	# ok this is the magic ;-)
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	if($useln -eq 1){
		$msg = @"
======================================================================
$timestamp

3.) RoboShot uses LN.EXE to hardlink unchanged files from
	$currentinterval.1 to $currentinterval.0
======================================================================
"@		
	}
	if($usefsutil -eq 1){
		$msg = @"
======================================================================
$timestamp

3.) RoboShot uses FSUTIL.EXE to hardlink unchanged files from
	$currentinterval.1 to $currentinterval.0
======================================================================
"@				
	}
	if($usemklink -eq 1){
		$msg = @"
======================================================================
$timestamp

3.) RoboShot uses MKLINK to hardlink unchanged files from
	$currentinterval.1 to $currentinterval.0
	Logfile: $logfilehardlinks
======================================================================
"@
	}	
	Write-Host $msg
	Out-File -filePath $logfilemain -InputObject $msg -Append
	$linkdest = Join-Path -Path $dest -ChildPath $currentinterval".1"
	$intervalroot = Join-Path -Path $dest -ChildPath $currentinterval".0"
	
	Get-Content $logfiletmpfiles | foreach-object {
		$ind1 = $_.indexof("тот же");
		$ind2 = $_.indexof(":");
		if(($ind1 -ge 0) -and ($ind2 -gt $ind1)){
			# выделяем имя файла из лога
			$filepathtolink = $_.substring($ind2-1+$Source.Length+1)
			# меняем < и > на соответствущие им кавычки
			#$filepathtolink = $filepathtolink -replace '<','«'
			#$filepathtolink = $filepathtolink -replace '>','»'
			$filepathtolink = $_.substring($ind2-1+$Source.Length+1)
			$tolink = Join-Path -Path $intervalroot -ChildPath $filepathtolink
			$fromlink = Join-Path -Path $linkdest -ChildPath $filepathtolink
			#Write-Host "$fromlink - $tolink"
			if($useln -eq 1){
				ln $fromlink $tolink >> $logfilehardlinks
			}
			if($usefsutil -eq 1){
				fsutil hardlink create $tolink $fromlink >> $logfilehardlinks
			}
			if($usemklink -eq 1){
				#try {
				#	Start-Process -FilePath "cmd.exe" -ArgumentList "/c mklink /H `"$tolink`" `"$fromlink`" 1>> `"$logfilehardlinks`" 2>>&1" -Wait -NoNewWindow
				#}
				#catch {
				#	Write-Host "Start-Process error at mklink to $fromlink - $tolink"
				#}
				#fsutil hardlink create $tolink $fromlink >> $logfilehardlinks
				try {
					New-Hardlink $tolink $fromlink
				}
				catch {
					Write-Host "$error[0] $tolink - $fromlink" 
				}
			}
		}
	}
	# 3.) --- now copy the new things that have changed since the last backup ---
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	$msg = @"
======================================================================
$timestamp

4.) RoboShot uses Robocopy to copy the new files from their source
	path to $currentinterval.0
======================================================================
"@
	Write-Host $msg
	Out-File -filePath $logfilemain -InputObject $msg -Append
	$intervalroot = Join-Path -Path $dest -ChildPath $currentinterval".0"
	Foreach ($Source in $src){
		$srcdest = Split-Path $Source -noQualifier
		$srcdrive = Split-Path $Source -Qualifier
		$srcdest = Join-Path $srcdrive[0] $srcdest
		#$intervaldest = Join-Path -Path $intervalroot -ChildPath $srcdest
		$intervaldest = $intervalroot
		robocopy.exe $Source $intervaldest /XD $exclpaths /XF $exclfiles /XJ /NP /NDL /E /R:2 /W:1 >> $logfilemain
		Clear-Variable intervaldest
	}
	# delete the temporary files
	# comment out when debugging
	if (Test-Path $logfiletmpfiles){
		Remove-Item $logfiletmpfiles
	}
	if (Test-Path $logfilehardlinks){
		Remove-Item $logfilehardlinks
	}
	$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
	$msg = @"
======================================================================
$timestamp

RoboShot finished backup with interval $currentinterval

======================================================================
======================================================================
"@
	Write-Host $msg
	Out-File -filePath $logfilemain -InputObject $msg -Append
	Return
}

function handle-Interval ($currentinterval, $dest, $interval){
	get-Intervaldata $currentinterval $interval

	# only for the lowest interval we need to rotate and copy
	if ($interval_num -eq 0){
		rotate-lowestsnapshots $currentinterval $dest $interval
		backup-lowestinterval $currentinterval $dest $interval $interval_num $interval_max $prev_interval $prev_interval_max
	}
	# for higher ones we only rotate
	else{
		rotate-higherinterval $currentinterval $dest $interval $interval_num $interval_max $prev_interval $prev_interval_max
	}	
	Return
}

# ===============================================
# === here it starts ============================
# ===============================================

# check the given commandline parameters
Get-Cmdlineparameters $cmdparas

# where is the TEMP - folder 
Set-Variable -Name tmp -Value (Get-Content ENV:TEMP) -Option ReadOnly -Scope Global -Force

Get-Logname $cfgfile

$timestamp = Get-Date -UFormat "%H:%M:%S %d.%m.%Y"
$msg = @"

======================================================================
======================================================================
$timestamp

RoboShot is starting ...
======================================================================
"@
Write-Host $msg
Out-File -filePath $logfilemain -InputObject $msg -Append

# get all data from config file
Get-Interval $cfgfile
Get-SrcPaths $cfgfile
Get-DestPaths $cfgfile
Get-DestPathType $cfgfile
Get-ExclPaths $cfgfile
Get-ExclFiles $cfgfile

# check for fsutil (XP), mklink (Windows 7) and ln.exe
Check-Tools

# handle the given interval and backup
handle-Interval $currentinterval $dest $interval

#Done! ;-)