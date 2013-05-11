# --- Install packages we need ---
package 'drbd8-utils'
package 'lvm2'
package 'linux-server'
package 'nfs-kernel-server'
#package 'cman'
package 'pacemaker'

# --- Add the data partition ---
directory '/data'

params = data_bag_item("nfs","parameters")
master_ip =params["master_ip"]
slave_ip = params["slave_ip"]
volume = params["volume"]
resource_name = params["drbd_resource"]
role = params["drbd_role"]
network = master_ip.rpartition(".")[0]
network = network + ".0"
case role
 when "master"
  tunnel_ip = "172.16.0.1"
  remote_ip = slave_ip
  local_ip = master_ip
 when "slave"
  tunnel_ip = "172.16.0.2"
  remote_ip = master_ip
  local_ip = slave_ip
end
tunnel_net = tunnel_ip.rpartition(".")[0]
tunnel_net = tunnel_net + ".0"

tun1_exist = `cat /etc/network/interfaces | grep tun1`

template "/etc/drbd.d/global_common.conf" do
  source "global_common.conf"
  variables(
   :resource_name => resource_name,
   :node1_ip => master_ip,
   :node2_ip => slave_ip,
   :volume => params["volume"],
   :device => params["device"]
 )
 notifies :start, "service[drbd]", :immediately
 notifies :run, 'execute[drbd-init]', :immediately
end

template "/etc/corosync/corosync.conf" do
  source "corosync.conf"
    variables(
      :bind_addr => tunnel_net
    )
end

template "/etc/default/corosync" do
  source "corosync"
end
#template "/etc/cluster/cluster.conf" do
#  source "cluster.conf"
#  notifies :start, "service[cman]", :immediately
#end

template "/etc/exports" do
  source "exports"
  variables(
   :network => network
  )
end

template "/etc/insserv/overrides/drbd" do
  source "drbd-overrides"
end

template "/etc/default/nfs-kernel-server" do
  source "nfs-kernel-server"
end

template "/etc/default/nfs-common" do
  source "nfs-common"
end

template "/etc/modprobe.d/local.conf" do
  source "local.conf"
end

template "/etc/pacemaker.conf" do
  source "pacemaker.conf"
  notifies :start, "service[corosync]", :immediate
  notifies :run, "execute[update-pacemaker-config]", :immediate
end

execute "update-pacemaker-config" do
  command "crm configure load replace /etc/pacemaker.conf"
  action :nothing
end

execute "drbd-init" do
 command "drbdadm create-md #{resource_name}; drbdadm -- --overwrite-data-of-peer primary all"
 action :nothing
end

execute "drbd-connect" do
 command "drbdadm connect #{resource_name}"
 action :nothing
end

service "drbd" do
 action :enable
end

#service "cman" do
# action :enable
#end

service "corosync" do
 action :enable
end


bash "add-tunnel-interface" do

  code <<-EOH
  echo "#AUTO Tunnel interface for cluster
auto tun1 
iface tun1 inet static 
address #{tunnel_ip}
network 172.16.0.0 
netmask 255.255.255.0 
pre-up ip tunnel add tun1 mode ipip remote #{remote_ip} local #{local_ip} ttl 255 
up ip link set mtu 1500 dev tun1 
up ifconfig tun1 multicast post-down ip tunnel del tun1" >>/etc/network/interfaces
EOH
notifies :run, "execute[ifconfig-tun1]", :immediately
not_if { tun1_exist != "" }
end

execute "ifconfig-tun1" do
  command "ifup tun1; ifconfig tun1 up"
  action :nothing
end
#mount '/mnt/data_joliss' do
#  action [:mount, :enable]  # mount and add to fstab
#  device 'data_joliss'
#  device_type :label
#  options 'noatime,errors=remount-ro'
#end

# --- Set host name ---
# Note how this is plain Ruby code, so we can define variables to
# DRY up our code:
#hostname = 'opinionatedprogrammer.com'

#file '/etc/hostname' do
#  content "#{hostname}\n"
#end

#service 'hostname' do
#  action :restart
#end

#file '/etc/hosts' do
#  content "127.0.0.1 localhost #{hostname}\n"
#end

# --- Deploy a configuration file ---
# For longer files, when using 'content "..."' becomes too
# cumbersome, we can resort to deploying separate files:
#cookbook_file '/etc/apache2/apache2.conf'
# This will copy cookbooks/op/files/default/apache2.conf (which
# you'll have to create yourself) into place. Whenever you edit
# that file, simply run "./deploy.sh" to copy it to the server.

#service 'apache2' do
#  action :restart
#end

