# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"
  # config.vm.provision :shell, path: "install.sh"
  # config.vm.box_check_update = false


  config.vm.network "forwarded_port", guest: 80, host: 8080
  # config.vm.network "private_network", ip: "192.168.33.10"
  # config.vm.network "public_network"

  config.ssh.forward_agent = true

  config.vm.synced_folder "./setup", "/setup_data"
  config.vm.synced_folder "./sources", "/usr/local/devel", mount_options:["dmode=777","fmode=777"]
  config.vm.synced_folder "./logs", "/var/log/devel", mount_options:["dmode=777","fmode=777"]

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.customize ["modifyvm", :id, "--memory", "1024"]
  end

end
