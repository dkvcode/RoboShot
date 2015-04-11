rem chcp 1251
net use Y: "\\192.168.x.x\backup" password /USER:login
robocopy "src_path" "Y:\dst_path" /E /Z /COPY:TD /DCOPY:T /M /PURGE /R:2 /W:30 /LOG:roboshot_path\logs\backup_arc_to_nas.log
net use Y: /delete /Y
pause