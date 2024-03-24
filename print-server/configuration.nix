{ config, pkgs, modulesPath, ... }: {
	imports = [
		"${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
		"${modulesPath}/profiles/minimal.nix"
		"${modulesPath}/profiles/headless.nix"
		../modules/auto-upgrade.nix
		../modules/ssh-wifi-access.nix
		../customization.nix
	];
	system.stateVersion = "23.11";
	nixpkgs.system = "aarch64-linux";
	environment.noXlibs = false;  # set true by minimal.nix, but causes binary cache misses

	# FIXME: SSH crashes with the Rust nscd implementation
	services.nscd.enableNsncd = false;

	# reduce writes to the SD card and enable trimming
	fileSystems."/".options = [ "noatime" ];
	fileSystems."/tmp" = {
		device = "none";
		fsType = "tmpfs";
		options = [ "mode=1777" ];
	};
	services.journald.extraConfig = "Storage=volatile";
	services.fstrim.enable = true;

	# add some swap because the Raspberry’s 512MB is too little for NixOS upgrades
	swapDevices = [{
		device = "/var/lib/swapfile";
		size = 4 * 1024;
	}];

	# CUPS printing with HP driver
	networking.hostName = "themisto";
	services.printing = {
		enable = true;
		startWhenNeeded = false;
		listenAddresses = [ "*:631" ];
		allowFrom = [ "all" ];
		openFirewall = true;
		drivers = [ pkgs.hplip ];
		browsing = true;
		defaultShared = true;
		extraConf = ''
			PreserveJobHistory No
			ReadyPaperSizes A4
		'';
	};
	hardware.printers.ensurePrinters = [{
		name = "HP_LaserJet_M15";
		description = "HP LaserJet M15";
		location = "Zuhause";
		deviceUri = "hp:/usb/HP_LaserJet_M14-M17?serial=JPCLB31842";
		model = "drv:///hp/hpcups.drv/hp-laserjet_m14-m17.ppd";
		ppdOptions.PageSize = "A4";
	}];
}
