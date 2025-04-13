{ config, pkgs, modulesPath, ... }: {
	imports = [
		"${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
		"${modulesPath}/profiles/headless.nix"
		../modules/auto-upgrade.nix
		../modules/conserve-storage.nix
		../modules/ssh-wifi-access.nix
		../customization.nix
	];
	system.stateVersion = "24.11";
	nixpkgs.hostPlatform = "aarch64-linux";

	# FIXME: SSH crashes with the Rust nscd implementation
	services.nscd.enableNsncd = false;

	# add some swap because the Raspberry’s 512MB is too little for NixOS upgrades
	swapDevices = [{
		device = "/var/lib/swapfile";
		size = 4 * 1024;
	}];

	# disable CUPS backends to reduce system size
	nixpkgs.overlays = [ (final: prev: {
		runCommand = name: env: command:
			if name == "additional-cups-backends" then
				(prev.runCommand name env "mkdir -p $out")
			else
				(prev.runCommand name env command);
	})];

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
