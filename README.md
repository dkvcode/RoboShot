# RoboShot

 This is RoboShot by Thomas Hiller with some modifications. Works on russian versions of Windows now. 
 CreateSchedule.bat is full snapshot sample for create a mirror of source directories to network SMB torage.
 WARNING! this bat-file wil change you powershell Set-ExecutionPolicy to Set-ExecutionPolicy remotesigned! If you don't need this option, yo will need to modify this line.
 archive.bat is full snapshot sample for create a mirror of source directories to network SMB storage.
 daily.bat is a daily backup sample.
 weekly.bat is a weekly backup sample.
 You will need to make some changes to bat-files and roboshot.ps1 file:
 roboshot_path is you RoboShot directory
 src_path if source directory
 dst_path if destination directory fo storing backups.
 All bat-files needs to be run as Administrator.

# Original README content by Thomas Hilles is below. Enjoy!
 
 author:  Thomas Hiller
 date:    17/03/2010
 version: 0.3

 url: https://sourceforge.net/projects/roboshot
 contact: please contact me via the sourceforge project site

This is the README.TXT for RoboShot


WHAT YOU NEED:
		Powershell (tested with v2)
			-for XP get it from:
			 http://www.microsoft.com/germany/technet/scriptcenter/hubs/msh.mspx
			 (sorry it's the german site)
			-included in Windows 7
			
		ROBOCOPY.EXE 
			-for XP get it from:
			 http://technet.microsoft.com/en-us/magazine/2006.11.utilityspotlight.aspx
			 (included in the Robocopy GUI)
			-included in Windows 7
		
		Only if your backup repository is a __remote__ NTFS or Samba share you need:
		LN.EXE 
			-get it for any Windows platform from:
			 http://schinagl.priv.at/nt/ln/ln.html
			-IMPORTANT: Follow the installation description ! ! !
			-copy ln.exe to the directory in you %PATH%-variable e.g. C:\Windows
			 otherwise RoboShot won't find it
			-the Vista versions works also for Windows 7
			-this great tool allows to hard link files within a NTFS volume (local and remote)
			 within RoboShot LN.EXE is only used for remote backups
			 Also works on Samba network shares when the filesystem on the server supports hard
			 links (I only tested with ext3)			 
			-IMPORTANT: when you backup on remote shares connect them before running RoboShot
						RoboShot doesn't check that until now
			-I also recommend to install the LinkShellExtensions from:
			 http://schinagl.priv.at/nt/hardlinkshellext/hardlinkshellext.html
			 is not necessary for running RoboShot but a nice thing to have ;-)
			
FILES:
		roboshot.ps1
		roboshot.cfg
		LICENSE.TXT
		README.TXT
		CHANGELOG

USAGE:
	A)	Tested and working with XP SP3 32 bit and Windows 7 32/64 bit.
		If it works with Windows Vista 32/64 bit let me know.
		Uses the ROBOCOPY \XJ switch to exclude junctions to avoid recursive
		backups. See the ROBOCOPY help.
		
	B)	Use the roboshot.cfg file to enter the configuration data that
		RoboShot needs to run:
			
		B1.) snapshot_root defines the Backup root directory.
			All snapshots will be stored under this directory.
			Should look like:
			
			snapshot_root=X:\folder\to\backup\root
			
			If the drive after a "snapshot_root=" (here X:) is not accesible, the script
			stops. If the backup root folder does not exists it is created.
			
		B2.) snapshot_roottype defines if the snapshot_root folder
			is a 'local' NTFS Volume (internal,usb) or a 'remote' NTFS or Smaba share
			There are only two valid options: local or remote
			Be correct here or hard linkinkg will fail (or no backup at all)!!!
			Should look like:
			
			snapshot_roottype=local
			
			'local' is the default option.
			If you use a local NTFS volume Windows built-in routines are used for creating
			the hard links and you don't need to download LN.EXE
			On XP FSUTIL.EXE and on Windows 7 MKLINK is used for creating local hard links.
			I skipped FSUTIL.EXE on Windows 7 because you need adminstrative priviliges to run
			it which is kind of inconvenient.
			For 'remote' backups you definitely need to download LN.EXE for creating hard links
			within remote NTFS or Samba shares. I tested Samba shares on a Linux server with ext3
			filesystem, so I assume if the filesystem on the server supports hard links LN.EXE
			can create them	through Samba.			
			
		B3.) interval defines the name and the amount of snapshots to keep
			Should look like:
			
			interval=hourly:6
			interval=daily:7
			
			from http://www.rsnapshot.org/howto/1.2/rsnapshot-HOWTO.en.html I copied the explanation
			of the interval definition and the procedure:
			4.3.7 interval
			rsnapshot has no idea how often you want to take snapshots.
			Everyone's backup scheme may be different. In order to specify how much data to save,
			you need to tell rsnapshot which "intervals" to keep, and how many of each. An interval,
			in the context of the rsnapshot config file, is a unit of time measurement. These can
			actually be named anything (as long as it's alphanumeric, and not a reserved word), but
			by convention we will call ours hourly and daily. In this example, we want to take a snapshot
			every four hours, or six times a day (these are the hourly intervals). We also want to
			keep a second set, which are taken once a day, and stored for a week (or seven days).
			This happens to be the default, so as you can see the config file reads:

			#interval=hourly:6
			interval=daily:7
			interval=weekly:4
			interval=monthly:12
			interval=yearly:5

			Please note that the hourly interval is specified first. This is very important.
			The first interval line is assumed to be the smallest unit of time, with each additional
			line getting successively larger. Thus, if you add a yearly interval, it should go at
			the bottom, and if you add a minutes interval, it should go before hourly. It's also worth
			noting that the snapshots get "pulled up" from the smallest interval to the largest.
			In this example, the daily snapshots get pulled from the oldest hourly snapshot,
			not directly from the main filesystem.		
		
		B4.) backup paths
			Should look like:
		
			backup=C:\folder to\backup
			
			You can give as many backup paths as you wish. Please give on path per line. The subfolders
			are of course included. If you want to exclude one subfolder give it as 'exclude_path' (see B.5)
			Give complete folder paths. If the folder you give does not exist you get an error message
			and the script stops.
			For the above examples the backup path would contain:
			X:\folder\to\backup\root\daily.0\C\folder to\backup
			X:\folder\to\backup\root\daily.1\C\folder to\backup
			X:\folder\to\backup\root\daily.2\C\folder to\backup
			X:\folder\to\backup\root\daily.3\C\folder to\backup
			X:\folder\to\backup\root\daily.4\C\folder to\backup
			X:\folder\to\backup\root\daily.5\C\folder to\backup
			X:\folder\to\backup\root\daily.6\C\folder to\backup
			X:\folder\to\backup\root\weekly.0\C\folder to\backup
			X:\folder\to\backup\root\weekly.1\C\folder to\backup
			X:\folder\to\backup\root\weekly.2\C\folder to\backup
			X:\folder\to\backup\root\weekly.3\C\folder to\backup
			
			after four weeks. Inside each of these directories is a "full" backup of that point in time.
			The destination directory paths you specified under the 'backup=' parameters get stuck directly
			under these directories.
		
		B5.) log file
			Should look like:
			
			logfile=D:\roboshot\param\roboshot.log
			
			Saves the logging output from RoboShot and from ROBOCOPY.
			If you specify nothing the log file will be written to the users
			%TEMP% directory and named "roboshot.log"		
		
		B6.) Exclude Folders
			Should look like:
		
			exclude_path=C:\folder\to exclude
		
			If uncommented the exclude path parameter \XD, is simply get passed directly
			to ROBOCOPY. If you have multiple exclude paths, put each one on a separate line.
			Check also the ROBOCOPY help.
			If you want to exclude nothing just comment it with #.
		
		B7.) Exclude Files
			Should look like:		
		
			exclude_files=*.bat
			
			If uncommented the exclude file parameter \XF, is simply get passed directly
			to ROBOCOPY. If you have multiple exclude files, put each one on a separate line.
			Check also the ROBOCOPY help.
			If you want to exclude nothing just comment it with #.
		
	C.) Commandline Parameters
	
		You can call RoboShot without any parameter or with 'help' , '-h' or '\?'
		to get a short help text:
		
			======================================================================
			You either started Roboshot without any parameter or by invoking
			'help' or '\?' or '-h'
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
			Version 0.1.5
			01/03/2010
			======================================================================
		
		As you see above with '-c' you can define an alternative configuration file.
		With this you can have different backup configurations be called at different times
	
		RoboShot is intended to be used like Rsnapshot.
		So create automated tasks which call the script roboshot.ps1
		with the additional interval parameter like:
		
		.\roboshot.ps1 daily
		
		or
		
		.\roboshot.ps1 -c "D:\path\to\config file" daily
		
		when you want to use an alternative configuration file.
		
		For more Information check the Rsnapshot Homepage
		http://rsnapshot.org/howto/1.2/rsnapshot-HOWTO.en.html#automation
		on how to use the autmated tasks.
		The procedure should be the same as under linux. But you don't use cron of course ;-).
		
	Enjoy!!!
