rem chcp 1251
powershell roboshot_path\roboshot.ps1 -c "roboshot_path\roboshot_src1.cfg" daily > roboshot_path\logs\roboshot_src1_daily.log
powershell roboshot_path\roboshot.ps1 -c "roboshot_path\roboshot_src2.cfg" daily > roboshot_path\logs\roboshot_src2_daily.log
del roboshot_path\logs\roboshot.log
net use Z: "\\192.168.x.x\backup" password /USER:login
robocopy "src_path1" "Z:\TB" /E /Z /COPY:TD /DCOPY:T /M /PURGE /R:2 /W:30 /LOG:roboshot_path\logs\backup_src1_to_nas.log
robocopy "src_path2" "Z:\1C" /E /Z /COPY:TD /DCOPY:T /M /PURGE /R:2 /W:30 /LOG:roboshot_path\backup_src2_to_nas.log
net use Z: /delete /Y