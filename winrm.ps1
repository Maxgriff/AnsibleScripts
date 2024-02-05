# Open Firewall For winrm
Set-NetFirewallRule -DisplayGroup "Windows Remote Management" -Profile Any

# Download and install npcap.  Unfortunately, you can't install unattended.
Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-1.78.exe" -OutFile "npcap.exe"
.\npcap.exe
