# Here are packages cobbler needs to have to work correctly

package "cobbler" do
  action :install
end

package "cobbler-web" do
  action :install
end

package "tftpd-hpa" do
  action :install
end

package "dnsmasq" do
  action :install
end


template "/etc/cobbler/modules.conf" do
  source "modules.conf.erb"
  mode 0644
  notifies :restart, "service[cobbler]", :immediately
end

template "/etc/cobbler/settings" do
  source "settings.erb"
  mode 0644
  variables(
            :next_server => node["cobbler"]["next_server"],
            :cobbler_server => node["cobbler"]["cobbler_server"]
  )
  notifies :restart, "service[cobbler]", :immediately
end


execute "cobbler_sync" do
  command "cobbler sync"
  action :nothing
end


template "/etc/cobbler/dnsmasq.template" do
  source "dnsmasq.template.erb"
  mode 0644
  variables(
            :dhcp_range => node["cobbler"]["dhcp_range"],
            :gateway => node["cobbler"]["gateway"]
            )
  notifies :run, "execute[cobbler_sync]", :immediately 
end

template "/etc/cobbler/pxe/pxedefault.template" do
  source "pxedefault.template.erb"
  mode 0644
  variables(
            :pxetimeout => node["cobbler"]["pxetimeout"]
            )
  notifies :run, "execute[cobbler_sync]", :immediately 
end


directory node["cobbler"]["bootstrap_images_dir"] do
  owner "root"
  group "root"
  mode "0755"
  recursive true
  action :create
end

directory node["cobbler"]["bootstrap_ks_mirror_dir"] do
  owner "root"
  group "root"
  mode "0755"
  recursive true
  action :create
end

service "cobbler" do
  supports :restart => true 
  action :nothing
end

service "dnsmasq" do
  supports :restart => true 
  action :nothing
end


# FIXME
# maybe separate recipe only needed for development to resolv mirantis private names

file "/etc/dnsmasq.d/mirantis.net.conf" do
  action :create
  content "server=/mirantis.net/172.18.16.4"
  mode 0644
  notifies :restart, "service[dnsmasq]", :immediately 
end



# Syncing bootstrap kernel

remote_file "#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/linux" do
  source "#{node["cobbler"]["bootstrap_kernel_url"]}"
  mode 0644
  action :nothing
end
 
http_request "HEAD #{node["cobbler"]["bootstrap_kernel_url"]}" do
  message ""
  url node["cobbler"]["bootstrap_kernel_url"]
  action :head
  if File.exists?("#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/linux")
    headers "If-Modified-Since" => File.mtime("#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/linux").httpdate
  end
  notifies :create, "remote_file[#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/linux]", :immediately
end


# Syncing bootstrap initrd

remote_file "#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/initrd.gz" do
  source "#{node["cobbler"]["bootstrap_initrd_url"]}"
  mode 0644
  action :nothing
end
 
http_request "HEAD #{node["cobbler"]["bootstrap_initrd_url"]}" do
  message ""
  url node["cobbler"]["bootstrap_initrd_url"]
  action :head
  if File.exists?("#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/initrd.gz")
    headers "If-Modified-Since" => File.mtime("#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/initrd.gz").httpdate
  end
  notifies :create, "remote_file[#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/initrd.gz]", :immediately
end




# FIXME 
 

execute "add_bootstrap_distro" do 
  command "cobbler distro add \
--name=bootstrap-precise-i386 \
--kernel=#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/linux \
--initrd=#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/initrd.gz \
--arch=i386 \
--breed=ubuntu \
--os-version=precise"
  action :run
  only_if "test -z `cobbler distro find --name bootstrap-precise-i386`"
end

execute "edit_bootstrap_distro" do 
  command "cobbler distro edit \
--name=bootstrap-precise-i386 \
--kernel=#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/linux \
--initrd=#{node["cobbler"]["bootstrap_ks_mirror_dir"]}/initrd.gz \
--arch=i386 \
--breed=ubuntu \
--os-version=precise"
  action :run
  only_if "test ! -z `cobbler distro find --name bootstrap-precise-i386`"
end


# FIXME

execute "add_bootstrap_profile" do
  command "cobbler profile add \
--name=bootstrap-precise-i386 \
--distro=bootstrap-precise-i386 \
--enable-menu=True \
--kopts=\"root=/dev/ram0 rw ramdisk_size=614400\""
  action :run
  only_if "test -z `cobbler profile find --name bootstrap-precise-i386`"
end

execute "edit_bootstrap_profile" do
  command "cobbler profile edit \
--name=bootstrap-precise-i386 \
--distro=bootstrap-precise-i386 \
--enable-menu=True \
--kopts=\"root=/dev/ram0 rw ramdisk_size=614400\""
  action :run
  only_if "test ! -z `cobbler profile find --name bootstrap-precise-i386`"
end

# FIXME

execute "add_bootstrap_system" do
  command "cobbler system add \
--name=default \
--profile=bootstrap-precise-i386 \
--netboot-enabled=1"
  action :run
  only_if "test -z `cobbler profile find --name default`"
end

execute "edit_bootstrap_system" do
  command "cobbler system edit \
--name=default \
--profile=bootstrap-precise-i386 \
--netboot-enabled=1"
  action :run
  only_if "test ! -z `cobbler profile find --name default`"
end




