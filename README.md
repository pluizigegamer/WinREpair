This is an Offline-capable PowerShell repair script for Windows & WinRE. Detects missing system files, DLLs, and corrupt services with modular scanning and targeted DISM/SFC auto-repairs.
I began this project because i wanted to see if i could run PowerShell in WinRE (Recovery Environment). and after i accomplished that i wanted to see if i could create a repair kit for it and i did.

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
