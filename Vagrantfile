Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"
  config.vm.box_version = "2004.01"
  config.disksize.size = '100GB'

  config.vm.define "smdw" do |node|
        node.vm.hostname = "smdw"
        node.vm.network :private_network, ip: "192.168.0.201"
	node.vm.network :forwarded_port, id: "ssh", guest: 22, host: 2201
        node.vm.provision :shell, reboot: true, :path => "disable_selinux.sh"
        node.vm.provision 'shell', inline: 'sestatus'
        node.vm.provision :shell, :path => "prerequisite_application_install.sh"
        node.vm.provision :shell, :path => "setup_host_params.sh"
  end
  config.vm.define "sdw1" do |node|
        node.vm.hostname = "sdw1"
        node.vm.network :private_network, ip: "192.168.0.202"
        node.vm.network :forwarded_port, id: "ssh", guest: 22, host: 2202
        node.vm.provision :shell, reboot: true, :path => "disable_selinux.sh"
        node.vm.provision 'shell', inline: 'sestatus'
        node.vm.provision :shell, :path => "prerequisite_application_install.sh"
        node.vm.provision :shell, :path => "setup_host_params.sh"
  end
  config.vm.define "sdw2" do |node|
        node.vm.hostname = "sdw2"
        node.vm.network :private_network, ip: "192.168.0.203"
        node.vm.network :forwarded_port, id: "ssh", guest: 22, host: 2203
        node.vm.provision :shell, reboot: true, :path => "disable_selinux.sh"
        node.vm.provision 'shell', inline: 'sestatus'
        node.vm.provision :shell, :path => "prerequisite_application_install.sh"
        node.vm.provision :shell, :path => "setup_host_params.sh"
  end
  config.vm.define "mdw" do |node|
        node.vm.hostname = "mdw"
        node.vm.network :private_network, ip: "192.168.0.200"
        node.vm.network "forwarded_port", guest: 5432, host: 5433
        node.vm.network :forwarded_port, id: "ssh", guest: 22, host: 2200
        node.vm.provision :shell, reboot: true, :path => "disable_selinux.sh"
        node.vm.provision 'shell', inline: 'sestatus'
        node.vm.provision :shell, :path => "prerequisite_application_install.sh"
        node.vm.provision :shell, :path => "setup_host_params.sh"
  end

  config.vm.provider "virtualbox" do |v|
    v.memory = 12288
    v.cpus = 2
  end

end
