{ config, lib, pkgs, ... }: {

	# this would be pulled in by sd-image.nix, but we know we are targeting a Raspberry
	disabledModules = [ "profiles/all-hardware.nix" ];

	options.hardware.raspberry-pi = {

		bootOrder = lib.mkOption {
			type = lib.types.listOf (lib.types.enum [
				"sd-card" "usb" "nvme"
			]);
			default = [ "sd-card" "usb" ];
			description = "Devices are checked for a bootable file system in this order.";
		};
	};

	config = let

		# Current uboot does not reliably boot the Raspberry Pi 5. Until this changes,
		# the official Raspberry boot process is used, booting to the vendor kernel.
		# https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_5
		# https://github.com/nvmd/nixos-raspberrypi

		flakeUrl = "github:nvmd/nixos-raspberrypi/251861d8e7e4806e185a8e41e09b3ad1e6e088e6";
		flake = builtins.getFlake flakeUrl;
		raspberryPkgs = flake.legacyPackages.aarch64-linux.linuxAndFirmware.v6_6_51;

		bootConfigFile = pkgs.runCommand "config.txt" {} (''
			cat <<- EOF > $out
				# This is a generated file. Do not edit!
				[all]
				arm_64bit=1
				avoid_warnings=1
				camera_auto_detect=1
				disable_overscan=1
				display_auto_detect=1
				enable_uart=1
				kernel=kernel.img
				dtoverlay=vc4-kms-v3d
		'' + lib.optionalString (!config.networking.wireless.enable) ''
				dtoverlay=disable-wifi
				dtoverlay=disable-bt
		'' + ''

				[cm4]
				otg_mode=1

				[pi4]
				arm_boost=1
			EOF
		'');
		updateFirmware = firwareDirectory: toplevel: ''
			set -e
			declare -a rename=()
			safeCopy() {
				if ! test -e "$2" || ! ${pkgs.diffutils}/bin/cmp -s "$1" "$2" ; then
					${pkgs.coreutils}/bin/cp "$1" "$2.tmp"
					rename+=("$2")
				fi
			}

			# copy firmware files
			safeCopy ${bootConfigFile} ${firwareDirectory}/config.txt
			for i in ${raspberryPkgs.raspberrypifw}/share/raspberrypi/boot/{start*.elf,*.dtb,bootcode.bin,fixup*.dat} ; do
				safeCopy "$i" "${firwareDirectory}/''${i##*/}"
			done
			${pkgs.coreutils}/bin/mkdir -p ${firwareDirectory}/overlays
			for i in ${raspberryPkgs.raspberrypifw}/share/raspberrypi/boot/overlays/* ; do
				safeCopy "$i" "${firwareDirectory}/overlays/''${i##*/}"
			done

			# copy kernel boot files
			safeCopy ${config.system.build.kernel}/Image ${firwareDirectory}/kernel.img
			safeCopy ${config.system.build.initialRamdisk}/initrd ${firwareDirectory}/initrd
			echo "${lib.concatStringsSep " " config.boot.kernelParams} init=${toplevel}/init" > ${firwareDirectory}/cmdline.txt.tmp
			rename+=("${firwareDirectory}/cmdline.txt")

			# move all files in place
			for i in "''${rename[@]}" ; do
				${pkgs.coreutils}/bin/mv "$i.tmp" "$i"
			done
		'';

	in {

		# keep the flake in the Nix store so it is not re-downloaded for auto-update
		system.extraDependencies = let
			recursiveInputs = x: [ x ] ++ map recursiveInputs (lib.attrValues x.inputs or {});
		in lib.unique (lib.flatten (recursiveInputs flake));

		# vendor firmware
		nixpkgs.overlays = [ (final: prev: {
			raspberrypifw = raspberryPkgs.raspberrypifw;
			raspberrypiWirelessFirmware = raspberryPkgs.raspberrypiWirelessFirmware;
			makeModulesClosure = x: prev.makeModulesClosure (x // { allowMissing = true; });
		})];

		# boot process and kernel
		hardware.enableRedistributableFirmware = true;
		boot = {
			loader.grub.enable = false;
			consoleLogLevel = 7;
			kernelPackages = pkgs.linuxPackagesFor raspberryPkgs.linux_rpi5;
			kernelParams = [
				"console=tty1"
				"root=PARTUUID=${lib.strings.removePrefix "0x" config.sdImage.firmwarePartitionID}-02"
				"rootfstype=ext4"
				"fsck.repair=yes"
				"rootwait"
			];
			initrd.availableKernelModules = [
				"usbhid"
				"usb_storage"
				"vc4"
				"pcie_brcmstb"  # required for the pcie bus to work
				"reset-raspberrypi"  # required for vl805 firmware to load
			];
		};

		# boot and firmware partition
		fileSystems."/boot/firmware".options = lib.mkForce [ "defaults" ];  # mount this partition
		sdImage = {
			firmwareSize = 128;
			populateFirmwareCommands = updateFirmware "firmware" config.system.build.toplevel;
			populateRootCommands = "";
		};

		# kernel and firmware update script
		system.build.installBootLoader = pkgs.writeShellScript "update-firmware" (updateFirmware "/boot/firmware" "$1");

		# configure boot device order
		systemd.services.raspberry-pi-boot-order = {
			description = "Boot Device Order";
			wantedBy = [ "multi-user.target" ];
			wants = [ "local-fs.target" ];
			after = [ "local-fs.target" ];
			serviceConfig.Type = "oneshot";
			script = let
				bootMap = { sd-card = "1"; usb = "4"; nvme = "6"; };
				bootOrder = lib.pipe config.hardware.raspberry-pi.bootOrder [
					(map (x: lib.getAttr x bootMap))
					lib.reverseList
					lib.concatStrings
					(x: "0xf" + x)
				];
			in ''
				config=${pkgs.raspberrypi-eeprom}/bin/rpi-eeprom-config
				if ! $config | grep -Fxq 'BOOT_ORDER=${bootOrder}' ; then
					$config | sed '
						# replace existing config entry
						/^BOOT_ORDER=/{
							s/=.*$/=${bootOrder}/
							# output the remaining input
							:loop
							n
							b loop
						}
						# if not found, append new entry
						''${
							s/$/\nBOOT_ORDER=${bootOrder}/
						}
					' > boot.conf
					$config --apply boot.conf
					rm boot.conf
				fi
			'';
		};
	};
}
