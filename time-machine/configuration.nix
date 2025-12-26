{ config, lib, pkgs, modulesPath, ... }: {
	imports = [
		"${modulesPath}/installer/sd-card/sd-image.nix"
		"${modulesPath}/profiles/headless.nix"
		../modules/auto-upgrade.nix
		../modules/conserve-storage.nix
		../modules/ssh-wifi-access.nix
		../customization.nix
		./raspberry.nix
	];
	system.stateVersion = "25.11";
	nixpkgs.system = "aarch64-linux";

	# FIXME: boot from USB as a temporary fallback
	hardware.raspberry-pi.bootOrder = [ "usb" "sd-card" ];

	# disable WiFi, Ethernet only
	networking.hostName = "chaldene";
	networking.wireless.enable = lib.mkForce false;

	# NVMe storage for backups
	fileSystems."/mnt/tm" = {
		autoFormat = true;
		device = "/dev/nvme0n1";
		fsType = "ext4";
	};

	# Samba server
	users.groups.time-machine = {};
	services.samba = {
		enable = true;
		nmbd.enable = false;
		openFirewall = true;
		settings.global = {
			"server smb encrypt" = "required";
			"add user script" = "${pkgs.writeShellScript "add-user" ''
				${pkgs.shadow}/bin/useradd \
					--home /var/empty --no-create-home \
					--shell /run/current-system/sw/bin/nologin \
					--comment 'time machine samba access' \
					--gid time-machine \
					$1
				mkdir -p -m 700 /mnt/tm/$1
				chown $1:time-machine /mnt/tm/$1
			''} %u";
			"delete user script" = "${pkgs.writeShellScript "delete-user" ''
				${pkgs.shadow}/bin/userdel $1
			''} %u";
		};
		settings."Time Machine" = {
			path = "/mnt/tm/%u";
			"read only" = "no";
			"fruit:aapl" = "yes";
			"fruit:time machine" = "yes";
			"vfs objects" = "catia fruit streams_xattr";
		};
	};

	# Samba-created users should be denied SSH login
	services.openssh.settings.AllowUsers = [ "root" ];

	# mDNS advertisements
	services.avahi.extraServiceFiles.time-machine = let
		capitalizedHostName =
			(lib.toUpper (lib.substring 0 1 config.networking.hostName)) +
			(lib.toLower (lib.substring 1 (-1) config.networking.hostName));
		shareName = lib.head (lib.remove "global" (lib.attrNames config.services.samba.settings));
	in ''<?xml version="1.0" standalone='no'?>
		<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
		<service-group>
			<name>${capitalizedHostName}</name>
			<service>
				<type>_smb._tcp</type>
				<port>445</port>
			</service>
			<service>
				<type>_adisk._tcp</type>
				<txt-record>dk0=adVN=${shareName},adVF=0x82</txt-record>
				<txt-record>sys=adVF=0x100</txt-record>
			</service>
			<service>
				<type>_device-info._tcp</type>
				<port>0</port>
				<txt-record>model=AirPort</txt-record>
			</service>
		</service-group>
	'';

	# auto-activate system upgrades when Samba is quiescent
	systemd.services.quiescent-activate = {
		description = "Quiescent Upgrade Activation";
		wantedBy = [ "multi-user.target" ];
		wants = [ "local-fs.target" ];
		after = [ "local-fs.target" ];
		path = [ config.services.samba.package config.systemd.package ];
		startAt = "06:00";
		script = ''
			currConf=$(readlink -f /run/current-system)
			nextConf=$(readlink -f /nix/var/nix/profiles/system)
			if test "$currConf" != "$nextConf" ; then
				# check for running Samba connections
				while ! smbstatus --processes --json | grep --quiet --fixed-strings '"sessions": {}' ; do
					echo "waiting for Samba to quiesce"
					sleep 300
				done
				# currently no running Samba connections: activate system upgrade
				currBoot=$(readlink /run/booted-system/{firmware,initrd,kernel,kernel-modules,systemd})
				nextBoot=$(readlink /nix/var/nix/profiles/system/{firmware,initrd,kernel,kernel-modules,systemd})
				if test "$currBoot" = "$nextBoot" ; then
					# switch configuration in a transient systemd unit, as this one may be stopped during switch
					systemd-run --service-type=exec --collect \
						/nix/var/nix/profiles/system/bin/switch-to-configuration switch
				else
					/nix/var/nix/profiles/system/bin/switch-to-configuration boot && reboot
				fi
			fi
		'';
	};
}
