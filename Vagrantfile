Vagrant.configure("2") do |config|

  # ==========================================================================
  # Vulnerable build (CTF target) — default machine, unchanged behavior.
  # `vagrant up` with no name brings this one up.
  # ==========================================================================
  config.vm.define "vulnerable", primary: true do |vulnerable|

    vulnerable.vm.box = "ubuntu/jammy64"
    vulnerable.vm.boot_timeout = 1200
    vulnerable.vm.hostname = "northernbridge"

    dev_mode = ENV["DEV_MODE"] == "1"

    if dev_mode
      vulnerable.vm.synced_folder ".", "/vagrant", disabled: false
      vulnerable.vm.synced_folder "./www", "/var/www/html",
        disabled: false, create: true

      vulnerable.vm.provision "shell", name: "banner", inline: <<~SHELL
        echo "===================================================="
        echo " Northernbridge-College-CTF - DEVELOPMENT MODE"
        echo " Host ./www -> VM /var/www/html"
        echo " GitHub source cloning DISABLED"
        echo "===================================================="
      SHELL
    else
      vulnerable.vm.synced_folder ".", "/vagrant", disabled: true
      vulnerable.vm.synced_folder "./www", "/var/www/northernbridge", disabled: true

      vulnerable.vm.provision "shell", name: "banner", inline: <<~SHELL
        echo "===================================================="
        echo " Northernbridge-College-CTF - CHALLENGE MODE"
        echo "===================================================="
      SHELL
    end

    vulnerable.vm.network "public_network"

    vulnerable.vm.provider "virtualbox" do |vb|
      vb.name = "Northernbridge-College-CTF"
      vb.memory = 2048
      vb.cpus = 2
    end

    vulnerable.vm.provision "shell",
      path: "infra/provision.sh",
      env: {
        "DEV_MODE"      => ENV["DEV_MODE"] || "0",
        "PORTAL_REPO"   => ENV["PORTAL_REPO"] || "",
        "PORTAL_BRANCH" => ENV["PORTAL_BRANCH"] || ""
      }

     # Re-runs on every `vagrant up`/`reload`, not just the first provision —
    # shows current NAT/Bridge IPs even after `vagrant halt` + `vagrant up`.
    vulnerable.vm.provision "shell",
      path: "infra/report-access.sh",
      run: "always",
      env: {
        "SITE_PORT" => "80",
        "DB_PATH"   => "/var/lib/northernbridge/college.db"
      }
  end

  # ==========================================================================
  # Hardened build (verification artifact) — only via `vagrant up hardened`.
  # Never starts automatically, never shares state with the machine above.
  # ==========================================================================
  config.vm.define "hardened", autostart: false do |hardened|

    hardened.vm.box = "ubuntu/jammy64"
    hardened.vm.boot_timeout = 1200
    hardened.vm.hostname = "northernbridge-hardened"

    dev_mode = ENV["DEV_MODE"] == "1"

    if dev_mode
      hardened.vm.synced_folder ".", "/vagrant", disabled: false
      hardened.vm.synced_folder "./hardened/www", "/var/www/html",
        disabled: false, create: true

      hardened.vm.provision "shell", name: "banner", inline: <<~SHELL
        echo "===================================================="
        echo " Northernbridge-College Hardened - DEVELOPMENT MODE"
        echo " Host ./hardened/www -> VM /var/www/html"
        echo " GitHub source cloning DISABLED"
        echo "===================================================="
      SHELL
    else
      hardened.vm.synced_folder ".", "/vagrant", disabled: true
      hardened.vm.synced_folder "./hardened/www", "/var/www/northernbridge-hardened",
        disabled: true

      hardened.vm.provision "shell", name: "banner", inline: <<~SHELL
        echo "===================================================="
        echo " Northernbridge-College Hardened Build"
        echo "===================================================="
      SHELL
    end

    hardened.vm.network "public_network"

    hardened.vm.provider "virtualbox" do |vb|
      vb.name = "Northernbridge-Hardened"
      vb.memory = 2048
      vb.cpus = 2
    end

    hardened.vm.provision "shell",
      path: "hardened/infra/hardened_provision.sh",
      env: {
        "DEV_MODE"      => ENV["DEV_MODE"] || "0",
        "PORTAL_REPO"   => ENV["PORTAL_REPO"] || "",
        "PORTAL_BRANCH" => ENV["PORTAL_BRANCH"] || ""
      }

      hardened.vm.provision "shell",
      path: "infra/report-access.sh",
      run: "always",
      env: {
        "SITE_PORT" => "80",
        "DB_PATH"   => "/var/lib/northernbridge/college.db"
      }
  end

end
