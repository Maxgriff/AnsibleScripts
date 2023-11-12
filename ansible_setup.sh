#!/bin/bash

echo "Installing Ansible"
sudo apt-add-repository -y ppa:ansible/ansible > /dev/null
sudo apt -y update > /dev/null
sudo apt -y install ansible > /dev/null
echo "Ansible Successfully Installed"

# Check if at least one host is provided
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 host1 [host2 ... hostN]"
    exit 1
fi

# Define the variables
inventory_file="/etc/ansible/hosts"
linux_file="linux.ini"
win_file="windows.ini"
man_file="manager.ini"
got_man=0

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
	    # Gets the ssh username and the ip address of the host
	    # Uncomment the read and echo lines if you are not using private key login for ssh
	    read -p "Enter SSH username: " ssh_username
	    #read -s -p "Enter SSH password" ssh_password
	    #echo
	    read -p "Enter ip address: " ip_addr

	    # Check if the current host is the wazuh manager and put info into the appropriate file
	    # Replace the echo lines with the commented out lines if you are not using private key login
	    if [ $got_man -eq 0 ]; then
	       read -p "Is this the Wazuh Manager? (y/n): " ans
	       if [ "$ans" -eq "y" ]; then
		  got_man=1
                  echo "$host ansible_host=$ip_addr ansible_user=$ssh_username" >> "$man_file"
                  #echo "$host ansible_host=$ip_addr ansible_user=$ssh_username" ansible_password=$ssh_password >> "$man_file"
	       else
                  echo "$host ansible_host=$ip_addr ansible_user=$ssh_username" >> "$linux_file"
                  #echo "$host ansible_host=$ip_addr ansible_user=$ssh_username" ansible_password=$ssh_password >> "$linux_file"
	       fi
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
	       if [ "$ans" -eq "y" ]; then
		  got_man=1
                  echo "$host ansible_host=$ip_addr ansible_user=$winrm_username ansible_password=$winrm_password ansible_connection=winrm ansible_winrm_server_cert_validation=ignore" >> "$man_file"
	       else
            	  echo "$host ansible_host=$ip_addr ansible_user=$winrm_username ansible_password=$winrm_password ansible_connection=winrm ansible_winrm_server_cert_validation=ignore" >> "$win_file"
	       fi
	    fi
            ;;
        *)
            echo "Invalid input. Specify 'l' for Linux or 'w' for Windows."
            exit 1
            ;;
    esac
done

# Append the host info into the /etc/ansible/hosts file
cat "$linux_file" | sudo tee -a "$inventory_file" > /dev/null
cat "$win_file" | sudo tee -a "$inventory_file" > /dev/null
cat "$man_file" | sudo tee -a "$inventory_file" > /dev/null

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

echo "Adding Templates"

# Make the templates directory if it doesn't exist
if [ ! -d /etc/ansible/templates ]; then
   sudo mkdir /etc/ansible/templates
fi

# Check if the dependencies are installed in current folder otherwise get from github and put into templates directory
if [ -f ./linux-suricata.j2 ]; then
   sudo cp ./linux-suricata.j2 /etc/ansible/templates
else
   sudo curl -o /etc/ansible/templates/linux-suricata.j2 https://raw.githubusercontent.com/Maxgriff/AnsibleScripts/develop/linux-suricata.j2
fi

if [ -f ./windows-suricata.j2 ]; then
   sudo cp ./windows-suricata.j2 /etc/ansible/templates
else
   sudo curl -o /etc/ansible/templates/windows-suricata.j2 https://raw.githubusercontent.com/Maxgriff/AnsibleScripts/develop/windows-suricata.j2
fi

