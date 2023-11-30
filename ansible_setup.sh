#!/bin/bash

# Check if yq is installed
command -v yq >/dev/null 2>&1 || { echo >&2 "Install yq before running the script"; exit 1; }

# Check if at least one host is provided
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 host1 [host2 ... hostN]"
    exit 1
fi

# Define the variables
inventory_file="$(pwd)/inventory/hosts.yaml"
linux_file="linux.yaml"
win_file="windows.yaml"
man_file="manager.yaml"
got_man=0
private_key=0

# Read in use host file location and store it, otherwise create directory inventory if it doesn't exist
read -p "Where is your hosts file? (Leave blank for default): " user_hosts

if [ ! "$user_hosts" = "" ]; then
   inventory_file=$user_hosts
   if [ ! -f $inventory_file ]; then
      echo "File $inventory_file does not exist"
      exit 1
   fi
else
   if [ ! -d inventory ]; then
      mkdir inventory
   fi
fi

# Create or overwrite the inventory file
touch "$linux_file"
touch "$win_file"
touch "$man_file"
echo -e "" >> $inventory_file

# Check if using private key log in

# Add each host to the inventory file with user-provided details
for host in "$@"; do
    read -p "Is '$host' a Linux or Windows host? (l/w): " os_type
    os_type=$(echo "$os_type" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    
    case "$os_type" in
        l|linux)
	    # Gets the ip, ssh username, and the password/private key
	    read -p "Enter ip address: " ip
	    read -p "Enter SSH username: " user
	    read -p "Are you using private key login? (y/n): " priv
	    
	    if [ "$priv" = "y" ]; then
	       private_key=1
	       read -p "Enter absolute path to private key: " priv_path
	       
	       # Input information into linux yaml file
	       host="$host" ip="$ip" yq -i '.linux.hosts.[env(host)].ansible_host = env(ip)' "$linux_file"
	       host="$host" user="$user" yq -i '.linux.hosts.[env(host)].ansible_user = env(user)' "$linux_file"
	       host="$host" priv_path="$priv_path" yq -i '.linux.hosts.[env(host)].ansible_private_key_file = env(priv_path)' "$linux_file"
	    else
	       read -s -p "Enter SSH password" password
	       echo
	       
	       # Input information into linux yaml file
	       host="$host" ip="$ip" yq -i '.linux.hosts.[env(host)].ansible_host = env(ip)' "$linux_file"
	       host="$host" user="$user" yq -i '.linux.hosts.[env(host)].ansible_user = env(user)' "$linux_file"
	       host="$host" password="$password" yq -i '.linux.hosts.[env(host)].ansible_password = env(password)' "$linux_file"
	    fi

	    # Check if the current host is the wazuh manager to add it to the manager group
	    if [ $got_man -eq 0 ]; then
	       read -p "Is this the Wazuh Manager? (y/n): " ans
	       if [ $ans = "y" ]; then
		  # Only have one wazuh manager
		  got_man=1
                  
                  # Check if using private key or password for login then input the corresponding info into manager yaml
		  if [ $private_key -eq "1" ]; then
	             host="$host" ip="$ip" yq -i '.manager.hosts.[env(host)].ansible_host = env(ip)' "$man_file"
	             host="$host" user="$user" yq -i '.manager.hosts.[env(host)].ansible_user = env(user)' "$man_file"
	             host="$host" priv_path="$priv_path" yq -i '.manager.hosts.[env(host)].ansible_private_key_file = env(priv_path)' "$man_file"
	          else
	             host="$host" ip="$ip" yq -i '.manager.hosts.[env(host)].ansible_host = env(ip)' "$man_file"
	             host="$host" user="$user" yq -i '.manager.hosts.[env(host)].ansible_user = env(user)' "$man_file"
	             host="$host" password="$password" yq -i '.manager.hosts.[env(host)].ansible_password = env(password)' "$man_file"
	          fi
	       fi
	    fi
	    echo
            ;;
        w|windows)
	    # Get the winrm username and password and the ip address to connect to
	    read -p "Enter winrm username: " user
            read -s -p "Enter winrm password: " password
	    echo
	    read -p "Enter ip address: " ip
	    
	    # Check if the current host is the wazuh manager and put info into the appropriate file
	    if [ $got_man -eq 0 ]; then
	       read -p "Is this the Wazuh Manager? (y/n): " ans
	       if [ $ans = "y" ]; then
		  got_man=1
		  host="$host" ip="$ip" yq -i '.manager.hosts.[env(host)].ansible_host = env(ip)' "$man_file"
	          host="$host" subnet="$subnet" yq -i '.manager.hosts.[env(host)].ansible_subnet = env(subnet)' "$man_file"
		  host="$host" user="$user" yq -i '.manager.hosts.[env(host)].ansible_user = env(user)' "$man_file"
		  host="$host" password="$password" yq -i '.manager.hosts.[env(host)].ansible_password = env(password)' "$man_file"
		  host="$host" yq -i '.manager.hosts.[env(host)].ansible_connection = "winrm"' "$man_file" 
		  host="$host" yq -i '.manager.hosts.[env(host)].ansible_winrm_scheme = "http"' "$man_file"
		  host="$host" yq -i '.manager.hosts.[env(host)].ansible_port = 5985' "$man_file"
		  host="$host" yq -i '.manager.hosts.[env(host)].ansible_winrm_transport = "ntlm"' "$man_file"
	       fi
	    fi

            host="$host" ip="$ip" yq -i '.windows.hosts.[env(host)].ansible_host = env(ip)' "$win_file"
	    host="$host" user="$user" yq -i '.windows.hosts.[env(host)].ansible_user = env(user)' "$win_file"
	    host="$host" password="$password" yq -i '.windows.hosts.[env(host)].ansible_password = env(password)' "$win_file"
	    host="$host" yq -i '.windows.hosts.[env(host)].ansible_connection = "winrm"' "$win_file" 
	    host="$host" yq -i '.windows.hosts.[env(host)].ansible_winrm_scheme = "http"' "$win_file"
	    host="$host" yq -i '.windows.hosts.[env(host)].ansible_port = 5985' "$win_file"
	    host="$host" yq -i '.windows.hosts.[env(host)].ansible_winrm_transport = "ntlm"' "$win_file"
            echo
	    ;;
        *)
            echo "Invalid input. Specify 'l' for Linux or 'w' for Windows."
            exit 1
            ;;
    esac
done

# Update/Append the host info into the inventory/hosts file
yq ea '. as $item ireduce ({}; . * $item )' $inventory_file $linux_file $man_file $win_file > $inventory_file

# Remove intermediate files
rm "$linux_file" "$win_file" "$man_file"
echo "Ansible inventory file '$inventory_file' updated successfully."
echo
echo "Installing Ansible Packages..."
echo

# Make sure community.general is installed with ansible
if [ $(ansible-galaxy collection list | grep community\\\.general | wc -l) -eq "0" ]; then
   ansible-galaxy collection install community.general
fi

# Make sure ansible.windows is installed with ansible
if [ $(ansible-galaxy collection list | grep ansible\\\.windows | wc -l) -eq "0" ]; then
   ansible-galaxy collection install ansible.windows
fi

echo "Adding Inventory to ansible.cfg"
if [ $(grep ";inventory=" /etc/ansible/ansible.cfg | wc -l) -eq 1 ]; then
   sudo sed -i "s@;inventory=/etc/ansible/hosts@inventory=$(echo $inventory_file)@g" /etc/ansible/ansible.cfg
else if [ $(grep "$inventoryfile" /etc/ansible/ansible.cfg | wc -l) -eq 0 ]; then
   sudo sed -i "s@inventory=@inventory=$(echo $inventory_file),@g" /etc/ansible/ansible.cfg
fi

