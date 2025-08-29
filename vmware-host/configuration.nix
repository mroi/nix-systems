{ config, pkgs, modulesPath, ... }: {
	imports = [
		"${modulesPath}/profiles/headless.nix"
		../modules/auto-upgrade.nix
		../modules/ssh-wifi-access.nix
		../customization.nix
	];
	system.stateVersion = "25.11";
	nixpkgs.system = "x86_64-linux";

	# boot configuration and file systems
	boot = {
		loader.grub = {
			device = "nodev";
			efiSupport = true;
			efiInstallAsRemovable = true;
			configurationLimit = 10;
		};
		growPartition = true;
	};
	fileSystems."/boot" = {
		device = "/dev/disk/by-label/ESP";
		fsType = "vfat";
	};
	fileSystems."/" = {
		autoResize = true;
		device = "/dev/disk/by-label/nixos";
		fsType = "ext4";
	};
	fileSystems."/mnt/vm" = {
		autoFormat = true;
		device = "/dev/nvme0n1";
		fsType = "ext4";
	};
	services.fstrim.enable = true;

	# WiFi firmware
	nixpkgs.config.allowUnfree = true;
	hardware = {
		firmware = [ pkgs.linux-firmware ];
		wirelessRegulatoryDatabase = true;
	};

	# hostname, IP address, user accounts
	networking = {
		hostName = "sinope";
		interfaces.eno1.ipv4.addresses = [{
			address = "192.168.10.2";
			prefixLength = 24;
		}];
	};
	security.sudo.wheelNeedsPassword = false;
	users.users = {
		michael = {
			isNormalUser = true;
			extraGroups = [ "wheel" ];
			openssh.authorizedKeys.keys = [
				config.customization.authorizedKey
			];
		};
		paula = {
			isNormalUser = true;
		};
	};
}
