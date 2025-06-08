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

		# FIXME: previous flake I used is now unmaintained, migrate to new flake
		oldFlake = builtins.getFlake "github:nix-community/raspberry-pi-nix/3bfda6add79c55f9bf143fac928f54484d450e87";
		board = "bcm2712";
		kernelVersion = "v6_6_51";

		flakeUrl = "github:nvmd/nixos-raspberrypi/4de3b249951c15f42c706a7fac7d6e2ff12dfdea";
		flake = builtins.getFlake flakeUrl;
		raspberryPkgs = flake.legacyPackages.aarch64-linux.linuxAndFirmware."${kernelVersion}";

		kernelParamsFile = pkgs.writeText "cmdline.txt" "${lib.concatStringsSep " " config.boot.kernelParams}";
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

	in {

		# keep firmware uncompressed for the Raspberry boot process
		nixpkgs.overlays = [ (final: prev: {
			raspberrypifw = oldFlake.packages.aarch64-linux.firmware.overrideAttrs {
				compressFirmware = false;
			};
			raspberrypiWirelessFirmware = oldFlake.packages.aarch64-linux.wireless-firmware.overrideAttrs {
				compressFirmware = false;
			};
			makeModulesClosure = x: prev.makeModulesClosure (x // { allowMissing = true; });
		})];

		# boot process and kernel
		hardware.enableRedistributableFirmware = true;
		boot = {
			loader = {
				grub.enable = false;
				initScript.enable = true;
			};
			consoleLogLevel = 7;
			kernelPackages = pkgs.linuxPackagesFor raspberryPkgs.linux_rpi5;
			kernelParams = [
				"console=tty1"
				"root=PARTUUID=${lib.strings.removePrefix "0x" config.sdImage.firmwarePartitionID}-02"
				"rootfstype=ext4"
				"fsck.repair=yes"
				"rootwait"
				"init=/sbin/init"
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
			# FIXME: replace with populate commands from flake
			populateFirmwareCommands = ''
				cp ${raspberryPkgs.linux_rpi5}/Image firmware/kernel.img
				cp ${kernelParamsFile} firmware/cmdline.txt
				cp -r ${pkgs.raspberrypifw}/share/raspberrypi/boot/{start*.elf,*.dtb,bootcode.bin,fixup*.dat,overlays} firmware/
				cp ${bootConfigFile} firmware/config.txt
			'';
			populateRootCommands = ''
				mkdir -p files/sbin
				ln -s ${config.system.build.toplevel}/init files/sbin/
			'';
		};

		# kernel and firmware migration script
		system.extraSystemBuilderCmds = let
			# FIXME: replace with populate commands from flake
			migrate-rpi-firmware = (import "${oldFlake}/rpi/default.nix" {
				pinned = null; core-overlay = null; libcamera-overlay = null;
			} {
				inherit lib pkgs;
				config = config // {
					raspberry-pi-nix = {
						inherit board;
						kernel-version = kernelVersion;
						uboot.enable = false;
						firmware-migration-service.enable = true;
						firmware-partition-label = "FIRMWARE";
					};
					hardware.raspberry-pi.config-output = bootConfigFile;
				};
			}).config.systemd.services.raspberry-pi-firmware-migrate.serviceConfig.ExecStart;
		in ''
			mkdir -p $out/bin
			cp ${migrate-rpi-firmware} $out/bin/migrate-rpi-firmware
		'';

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
