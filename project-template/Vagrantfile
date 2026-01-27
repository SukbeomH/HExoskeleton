# Vagrantfile for Safe Agent Execution
# Based on: https://blog.emilburzo.com/2026/01/running-claude-code-dangerously-safely/

vm_name = "agent-sandbox-" + File.basename(Dir.getwd)

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  # Forward port for web apps (adjust as needed)
  config.vm.network "forwarded_port", guest: 3000, host: 3000, auto_correct: true

  # Sync current directory to /agent-workspace
  config.vm.synced_folder ".", "/agent-workspace", type: "virtualbox"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = 2
    vb.gui = false
    vb.name = vm_name
    vb.customize ["modifyvm", :id, "--audio", "none"]
    vb.customize ["modifyvm", :id, "--usb", "off"]
  end

  config.vm.provision "shell", inline: <<-SHELL
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y docker.io nodejs npm git unzip

    # Install Claude Code (optional, can be replaced with other agent tools)
    npm install -g @anthropic-ai/claude-code --no-audit

    # Setup permissions
    usermod -aG docker vagrant
    chown -R vagrant:vagrant /agent-workspace
  SHELL
end
