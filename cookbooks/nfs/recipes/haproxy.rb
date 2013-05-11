# --- Install packages we need ---
package 'haproxy'

# --- Add the data partition ---

params = data_bag_item("nfs","parameters")
master_ip =params["master_ip"]
slave_ip = params["slave_ip"]

template "/etc/default/haproxy" do
  source "haproxy"
end

template "/etc/haproxy/haproxy.cfg" do
  source "haproxy.cfg"
  variables(
   :master_ip => master_ip,
   :slave_ip => slave_ip,
 )
 notifies :start, "service[haproxy]", :immediately
end


service "haproxy" do
 action :enable
end

