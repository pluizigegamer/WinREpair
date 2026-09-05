This is an Offline-capable PowerShell repair script for Windows & WinRE. Detects missing system files, DLLs, and corrupt services with modular scanning and targeted DISM/SFC auto-repairs.
I began this project because i wanted to see if i could run PowerShell in WinRE (Recovery Environment). and after i accomplished that i wanted to see if i could create a repair kit for it and i did.

# Please note this DOES NOT work with WIFI. only ETHERNET. Ethernet adapters do work

You can find the script for the Fliper zero as main.txt
here are the steps to make this work without the Flipper zero:

STEP 1.
Type: wpeinit 
to make networking avaible

STEP 2.
To test if it worked you can type: ping github.com
If you get a response it means it works and you can continue. else try to type wpeinit again and try to ping it again

STEP 3.
Next type this exact line: irm https://pluizigegamer.github.io/WinREpair/main.ps1 | iex
Uppercase sensitive

STEP 4. 
Press enter and follow the menu. If you get any error's Issue me

ps: at step 2 if it doesn't work please run: for /r "C:\Windows\System32\DriverStore\FileRepository" %i in (.inf) do drvload "%i". and that worked.
and then type wpeinit again. if it didn't work try it with an ethernet adapter. from ethernet to usb-a/c and do the for command again. if that doesn't fix it search up how to load the ethernet drivers.
