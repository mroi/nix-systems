{ config, lib, pkgs, modulesPath, ... }: {
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
	systemd.services.vm-user-directories = {
		description = "Create per-user directories for virtual machines.";
		wantedBy = [ "multi-user.target" ];
		wants = [ "local-fs.target" ];
		after = [ "local-fs.target" ];
		serviceConfig.Type = "oneshot";
		script = let
			normalUsers = lib.concatStringsSep " " (
				builtins.attrNames (
					lib.filterAttrs
						(name: value: value.isNormalUser)
						config.users.users
				)
			);
		in ''
			for user in ${normalUsers} ; do
				if ! test -d /mnt/vm/$user ; then
					mkdir -m 700 /mnt/vm/$user
					chown $user:users /mnt/vm/$user
				fi
			done
		'';
	};
	services.fstrim.enable = true;

	# AMD GPU for wayland, WiFi firmware
	nixpkgs.config.allowUnfree = true;
	boot = {
		kernelParams = lib.mkForce [ "panic=1" "boot.panic_on_fail" ];
		extraModprobeConfig = "options amdgpu virtual_display=0000:0c:00.0,1";
		blacklistedKernelModules = [ "nouveau" ];
	};
	hardware = {
		firmware = [ pkgs.linux-firmware ];
		wirelessRegulatoryDatabase = true;
		graphics.enable = true;
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
