@echo off
echo Disabling ICS and HNS (Host Network Service)...
sc config SharedAccess start=disabled
sc failure SharedAccess reset=0 actions=none/none/none
sc config hns start=disabled
sc failure hns reset=0 actions=none/none/none
echo.
echo Both set to disabled. After reboot they will NOT start.
echo.
echo REBOOT NOW? (close this window and restart)
pause
