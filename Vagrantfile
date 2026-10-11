Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"
  config.vm.boot_timeout = 1200
  config.vm.hostname = "northernbridge"

  # --------------------------------------------------------------------------
  # Development mode
  #
  # Enable with:
  #
  #   $env:DEV_MODE = "1"       # PowerShell
  #   vagrant up
  #
  # In development mode ./www on the host is directly synced into the VM.
  # Therefore PHP/HTML/CSS/JS changes made on the host are immediately
  # available to Apache without cloning/rsyncing from GitHub.
  # --------------------------------------------------------------------------

  dev_mode = ENV["DEV_MODE"] == "1"

  if dev_mode
    puts "===================================================="
    puts " Northernbridge-College-CTF - DEVELOPMENT MODE"
    puts " Host ./www -> VM /var/www/html"
    puts " GitHub source cloning DISABLED"
    puts "===================================================="

  config.vm.synced_folder ".", "/vagrant",
  disabled: false

  config.vm.synced_folder "./www", "/var/www/html",
      disabled: false,
      create: true

  else
    # ------------------------------------------------------------------------
    # Production / reproducible mode
    #
    # No synced application folder. The provisioning script clones the
    # configured GitHub repository into the VM.
    # ------------------------------------------------------------------------

    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.synced_folder "./www", "/var/www/northernbridge", disabled: true
  end

  # Access the site from other devices on the same LAN (bridged):
  # http://<VM-IP>/
  config.vm.network "public_network"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "Northernbridge-College-CTF"
    vb.memory = 2048
    vb.cpus = 2
  end

  # --------------------------------------------------------------------------
  # Provisioning
  # --------------------------------------------------------------------------

  config.vm.provision "shell",
                      path: "infra/provision.sh",
                      env: {
                        "DEV_MODE"      => ENV["DEV_MODE"] || "0",
                        "PORTAL_REPO"   => ENV["PORTAL_REPO"] || "",
                        "PORTAL_BRANCH" => ENV["PORTAL_BRANCH"] || ""
                      }

end