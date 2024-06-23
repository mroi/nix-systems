{ lib, pkgs, raspberry, modulesPath, ... }: {
	imports = [
		raspberry.nixosModules.raspberry-pi
		"${modulesPath}/profiles/headless.nix"
		../modules/auto-upgrade.nix
		../modules/conserve-storage.nix
		../modules/ssh-wifi-access.nix
		../customization.nix
	];
	system.stateVersion = "24.11";
	nixpkgs.system = "aarch64-linux";

	# disable WiFi, Ethernet only
	networking.hostName = "chaldene";
	networking.wireless.enable = lib.mkForce false;

	# NVMe storage for backups
	fileSystems."/mnt/tm" = {
		autoFormat = true;
		label = "time-machine";
		device = "/dev/nvme0n1";
		fsType = "ext4";
	};

	# Samba server
	users.groups.time-machine = {};
	services.samba = {
		enable = true;
		enableNmbd = false;
		openFirewall = true;
		extraConfig = ''
			server smb encrypt = required
			add user script = ${pkgs.writeShellScript "add-user" ''
				${pkgs.shadow}/bin/useradd \
					--home /var/empty --no-create-home \
					--shell /run/current-system/sw/bin/nologin \
					--comment 'time machine samba access' \
					--gid time-machine \
					$1
				mkdir -p -m 700 /mnt/tm/$1
				chown $1:time-machine /mnt/tm/$1
			''} %u
			delete user script = ${pkgs.writeShellScript "delete-user" ''
				${pkgs.shadow}/bin/userdel $1
			''} %u
		'';
		shares = {
			"Time Machine" = {
				path = "/mnt/tm/%u";
				"read only" = "no";
				"fruit:aapl" = "yes";
				"fruit:time machine" = "yes";
				"vfs objects" = "catia fruit streams_xattr";
			};
		};
	};
}
