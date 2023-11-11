#!/bin/bash

# Check if at least one host is provided
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 host1 [host2 ... hostN]"
    exit 1
fi

# Define the variables
inventory_file="/etc/ansible/hosts"
linux_file="linux.ini"
win_file="windows.ini"
man_file="manager.txt"
got_man=0
ans="n"

# Create or overwrite the inventory file
echo -e "[linux_hosts]" > "$linux_file"
echo -e "\n[windows_hosts]" > "$win_file"
echo -e "\n[manager]" > "$man_file"

# Add each host to the inventory file with user-provided details
for host in "$@"; do
    read -p "Is '$host' a Linux or Windows host? (l/w): " os_type
    os_type=$(echo "$os_type" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    
    case "$os_type" in
        l|linux)
	    read -p "Enter SSH username: " ssh_username
	    read -p "Enter ip address: " ip_addr
	    if [ $got_man -eq 0 ]; then
	       read -p "Is this the Wazuh Manager? (y/n): " ans
	       if [ $ans -eq "y"]; then
		  got_man=1
                  echo "$host ansible_host=$ip_addr ansible_user=$ssh_username" >> "$man_file"
	       else
                  echo "$host ansible_host=$ip_addr ansible_user=$ssh_username" >> "$linux_file"
	       fi
	    fi
            ;;
        w|windows)
	    read -p "Enter SSH username: " ssh_username
            read -s -p "Enter SSH password: " ssh_password
	    echo
	    read -p "Enter ip address: " ip_addr
	    if [ $got_man -eq 0 ]; then
	       read -p "Is this the Wazuh Manager? (y/n): " ans
	       if [ $ans -eq "y"]; then
		  got_man=1
                  echo "$host ansible_host=$ip_addr ansible_user=$ssh_username" >> "$man_file"
	       else
            	  echo "$host ansible_host=$ip_addr ansible_user=$ssh_username ansible_password=$ssh_password ansible_connection=winrm ansible_winrm_server_cert_validation=ignore" >> "$win_file"
	       fi
	    fi
            ;;
        *)
            echo "Invalid input. Specify 'l' for Linux or 'w' for Windows."
            exit 1
            ;;
    esac
done


cat "$linux_file" | sudo tee -a "$inventory_file" > /dev/null
cat "$win_file" | sudo tee -a "$inventory_file" > /dev/null
rm "$linux_file" "$win_file"

echo "Ansible inventory file '$inventory_file' updated successfully."
