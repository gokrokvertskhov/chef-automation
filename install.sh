
#!/bin/bash

# This runs as root on the server
echo "This script helps to setup NFS HA Server"
echo "You need to run this script on both NFS nodes and provide the SAME parameters for this script"
echo "The following parameters will be asked"
echo "  Master IP - IP address of the first node. All nodes are equal but we need to setup DRBD and all data should be configured on master."
echo "  Slave IP - IP address of the second node. It will take DRBD data during syncronization."
echo "  Volume device - name of device for attached Volume. It is /dev/vdc by default."
echo "  DRBD device name - name of drdb device. Default value is /dev/drbd0."
echo "  Node role - specifies the role of current machine. The options are 'master' or 'slave'."
echo

kernel_v=`uname -r`
required_kernel="3.2.0-41-virtual"

if [ "$kernel_v" != "$required_kernel" ]; then
  echo "You need to update the kernel version. Do you want to install new kernel and reboot? [y\n]"
  read answer
  if [ "$answer" == "y" ]; then
    echo "You will need to start this script again after reboot."
    sleep 5
    apt-get install linux-image-extra-virtual
    reboot
  fi
fi

chef_binary=/var/lib/gems/1.9.1/gems/chef-11.4.4/bin/chef-solo

echo "Configuration..."
echo -n "Installation type nfs\haproxy?[nfs]:"
read install_type
if [ "$install_type" == "" ]; then
  install_type="nfs"
fi
echo -n "Master IP:"
read master_ip
echo -n "Slave IP:"
read slave_ip
if [ "$install_type" == "nfs" ]; then
  echo -n "Attached volume device [/dev/vdc]:"
  read volume_device
  echo -n "DRBD device [/dev/drbd0]:"
  read drbd_device
  echo -n "Machine Role [master]:"
  read role
fi
 
if [ "$volume_device" == "" ]; then
 volume_device="/dev/vdc"
fi

if [ "$drbd_device" == "" ]; then
 drbd_device="/dev/drbd0"
fi

if [ "$role" == "" ]; then
  role="master"
fi
mkdir /var/chef-solo > /dev/nul
mkdir /var/chef-solo/data_bags > /dev/nul
mkdir /var/chef-solo/data_bags/nfs/ > /dev/nul

echo  "{
 \"id\": \"parameters\",
 \"master_ip\": \"$master_ip\",
 \"slave_ip\" : \"$slave_ip\",
 \"drbd_resource\" : \"r0\",
 \"volume\" : \"$volume_device\",
 \"device\" : \"$drbd_device\",
 \"drbd_role\": \"$role\"
}" > /var/chef-solo/data_bags/nfs/parameters.json

# Are we on a vanilla system?
if ! test -f "$chef_binary"; then
    export DEBIAN_FRONTEND=noninteractive
    # Upgrade headlessly (this is only safe-ish on vanilla systems)
    aptitude update &&
    #apt-get -o Dpkg::Options::="--force-confnew" \
    #    --force-yes -fuy dist-upgrade &&
    # Install Ruby and Chef
    aptitude install -y ruby1.9.1 ruby1.9.1-dev make &&
    sudo gem1.9.1 install --no-rdoc --no-ri chef 
fi 

if [ "$install_type" == "nfs" ]; then
  echo "{
      \"run_list\": [ \"recipe[nfs::default]\" ]
      }" > solo.json
fi

if [ "$install_type" == "haproxy" ]; then
  echo "{
      \"run_list\": [ \"recipe[nfs::haproxy]\" ]
      }" > solo.json
fi

chef-solo -c solo.rb -j solo.json
