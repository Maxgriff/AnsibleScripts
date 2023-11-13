#!/bin/bash

# Check if at least one host is provided
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 host1 [host2 ... hostN]"
    exit 1
fi

# Define the variables
inventory_file="inventory/hosts"
linux_file="linux.ini"
win_file="windows.ini"
man_file="manager.ini"
got_man=0
private_key=0

# Create or overwrite the inventory file
echo -e "[linux_hosts]" > "$linux_file"
echo -e "\n[windows_hosts]" > "$win_file"
echo -e "\n[manager]" > "$man_file"

# Check if using private key log in

# Add each host to the inventory file with user-provided details
for host in "$@"; do
    read -p "Is '$host' a Linux or Windows host? (l/w): " os_type
    os_type=$(echo "$os_type" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    
    case "$os_type" in
        l|linux)
	    # Gets the ssh username and the ip address of the host
	    # Uncomment the read and echo lines if you are not using private key login for ssh
	    read -p "Enter SSH username: " ssh_username

	    read -p "Are you using private key login? (y/n): " priv
	    if [ "$priv" = "y" ]; then
	       private_key=1
	       read -p "Enter absolute path to private key: " priv_path
	    else
	       read -s -p "Enter SSH password" ssh_password
	       echo
	    fi

	    read -p "Enter ip address: " ip_addr

	    # Check if the current host is the wazuh manager and put info into the appropriate file
	    if [ $got_man -eq 0 ]; then
	       read -p "Is this the Wazuh Manager? (y/n): " ans
	       if [ $ans = "y" ]; then
		  got_man=1
	    	  
                  # Check if using private key or password for login
		  if [ $private_key -eq "1" ]; then
	             echo "$host ansible_host=$ip_addr ansible_home=/etc/$ssh_username/ ansible_user=$ssh_username" ansible_ssh_private_key_file="$priv_path" >> "$man_file"
		     private_key=0
	          else
		     echo "$host ansible_host=$ip_addr ansible_home=/etc/$ssh_username/ ansible_user=$ssh_username" ansible_password=$ssh_password >> "$man_file"
	          fi
	       fi
	    fi

	    # Check if using private key or password for login
            if [ $private_key -eq "1" ]; then
	       echo "$host ansible_host=$ip_addr ansible_home=/etc/$ssh_username/ ansible_user=$ssh_username" ansible_ssh_private_key_file="$priv_path" >> "$linux_file"
	       private_key=0
	    else
	       echo "$host ansible_host=$ip_addr ansible_home=/etc/$ssh_username/ ansible_user=$ssh_username" ansible_password=$ssh_password >> "$linux_file"
	    fi
            ;;
        w|windows)
	    # Get the winrm username and password and the ip address to connect to
	    read -p "Enter winrm username: " winrm_username
            read -s -p "Enter winrm password: " winrm_password
	    echo
	    read -p "Enter ip address: " ip_addr
	    
	    # Check if the current host is the wazuh manager and put info into the appropriate file
	    if [ $got_man -eq 0 ]; then
	       read -p "Is this the Wazuh Manager? (y/n): " ans
	       if [ $ans = "y" ]; then
		  got_man=1
                  echo "$host ansible_host=$ip_addr ansible_home=C:\\Users\\$winrm_username\\ ansible_user=$winrm_username ansible_password=$winrm_password ansible_connection=winrm ansible_winrm_server_cert_validation=ignore" >> "$man_file"
	       fi
	    fi
            echo "$host ansible_host=$ip_addr ansible_home=C:\\Users\\$winrm_username\\ ansible_user=$winrm_username ansible_password=$winrm_password ansible_connection=winrm ansible_winrm_server_cert_validation=ignore" >> "$win_file"
            ;;
        *)
            echo "Invalid input. Specify 'l' for Linux or 'w' for Windows."
            exit 1
            ;;
    esac
done

# Append the host info into the inventory/hosts file
cat "$linux_file" >> "$inventory_file"
cat "$win_file" >> "$inventory_file"
cat "$man_file" >> "$inventory_file"

# Remove intermediate files
rm "$linux_file" "$win_file" "$man_file"
echo "Ansible inventory file '$inventory_file' updated successfully."

echo "Installing Ansible Packages"

# Make sure community.general is installed with ansible
if [ $(ansible-galaxy collection list | grep community\\\.general | wc -l) -eq "0" ]; then
   ansible-galaxy collection install community.general
fi

# Make sure ansible.windows is installed with ansible
if [ $(ansible-galaxy collection list | grep ansible\\\.windows | wc -l) -eq "0" ]; then
   ansible-galaxy collection install ansible.windows
fi

echo "Adding Inventory to ansible.cfg"
sudo sed -i "s@;inventory=/etc/ansible/hosts@inventory=$(pwd)/inventory/hosts" /etc/ansible/ansible.cfg
