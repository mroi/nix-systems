{ config, lib, pkgs, modulesPath, ... }: {
	imports = [
		"${modulesPath}/profiles/headless.nix"
		../modules/auto-upgrade.nix
		../modules/ssh-wifi-access.nix
		../customization.nix
	];
	system.stateVersion = "24.11";
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
		serviceConfig = { Type = "oneshot"; };
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
					if test $user = michael ; then
						# support synching and backup of the sunshine state file
						ln -s /var/lib/sunshine/sunshine.json /mnt/vm/$user/sunshine.json
						chown --no-dereference $user:users /mnt/vm/$user/sunshine.json
					fi
				fi
			done
		'';
	};
	services.fstrim.enable = true;

	# AMD GPU for wayland, WiFi firmware
	nixpkgs.config.allowUnfree = true;
	boot = {
		kernelParams = lib.mkForce [ "panic=1" "boot.panic_on_fail"
			"video=Virtual-1:5120x2880@60"
		];
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
		sunshine = {
			isSystemUser = true;
			linger = true;
			group = "sunshine";
			extraGroups = [ "video" "input" "seat" ];
			home = "/var/lib/sunshine";
			homeMode = "750";
			createHome = true;
		};
		michael = {
			isNormalUser = true;
			linger = true;
			extraGroups = [ "wheel" "sunshine" ];
			openssh.authorizedKeys.keys = [
				config.customization.authorizedKey
			];
		};
		paula = {
			isNormalUser = true;
			linger = true;
			extraGroups = [ "sunshine" ];
		};
	};
	users.groups.sunshine = {};

	# system-wide sunshine desktop streaming from a wayland display server
	services = {
		udev.extraRules = ''
			# sunshine forwards remote input, so uinput must be accessible by group
			KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
		'';
		seatd.enable = true;  # needed to allow AMDGPU access without a logged-in user
	};
	networking.firewall = {
		allowedTCPPorts = [ 47984 47989 47990 48010 ];
		allowedUDPPorts = [ 47998 47999 48000 48002 ];
	};
	systemd.services.sunshine = {
		description = "Sunshine desktop streaming from a wayland display server.";
		wantedBy = [ "multi-user.target" ];
		wants = [ "network-online.target" "vm-user-directories.service" ];
		after = [ "network-online.target" "vm-user-directories.service" ];
		serviceConfig = {
			User = "sunshine";
			Group = "sunshine";
			Restart = "always";
		};
		script = ''
			# prepare configuration files
			mkdir --parents --mode=700 "$HOME/.config/labwc"
			ln -snf ${./labwc-rc.xml} "$HOME/.config/labwc/rc.xml"
			mkdir --parents --mode=700 "$HOME/.config/sunshine"
			ln -snf ${import ./sunshine-apps { inherit config pkgs; }} "$HOME/.config/sunshine/apps.json"
			ln -snf ../../sunshine.json "$HOME/.config/sunshine/sunshine_state.json"
			# prepare runtime dir so other users can access wayland socket
			export XDG_RUNTIME_DIR="/run/user/$UID"
			chmod 750 "$XDG_RUNTIME_DIR"
			# configure keyboard layout
			export XKB_DEFAULT_LAYOUT=${config.console.keyMap}
			export XKB_DEFAULT_VARIANT=mac
			# set cursor theme for HiDPI mouse pointer
			export XCURSOR_PATH=${pkgs.adwaita-icon-theme}/share/icons
			export XCURSOR_THEME=Adwaita
			# start wayland compositor using AMD GPU
			export WLR_DRM_DEVICES=$(readlink -f '/dev/dri/by-path/pci-0000:0c:00.0-card')
			export WLR_RENDER_DRM_DEVICE=$(readlink -f '/dev/dri/by-path/pci-0000:0c:00.0-render')
			# FIXME: https://github.com/NixOS/nixpkgs/issues/229108
			#export WLR_RENDERER=vulkan
			export DRI_PRIME=pci-0000_0c_00_0!
			${pkgs.labwc}/bin/labwc &
			export WAYLAND_DISPLAY=wayland-0
			while ! test -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ; do sleep 1 ; done
			chmod 666 "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
			# desktop background color
			${pkgs.swaybg}/bin/swaybg --color '#3d454c' &
			# start sunshine server
			exec ${pkgs.sunshine}/bin/sunshine capture=wlr encoder=vaapi adapter_name=$WLR_RENDER_DRM_DEVICE
		'';
	};

	# scripts to launch user apps on system-wide sunshine desktop
	environment.systemPackages = [
		(pkgs.writeShellScriptBin "sunshine-prepare" ''
			# defaults for unset variables
			SUNSHINE_CLIENT_WIDTH="''${SUNSHINE_CLIENT_WIDTH:-5120}"
			SUNSHINE_CLIENT_HEIGHT="''${SUNSHINE_CLIENT_HEIGHT:-2880}"
			RESOLUTION="''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}"
			if test -z "$DISPLAY_SCALE" ; then
				if test "$SUNSHINE_CLIENT_HEIGHT" -gt 1700 ; then
					DISPLAY_SCALE=2
				else
					DISPLAY_SCALE=1
				fi
			fi
			# set desired resolution
			export XDG_RUNTIME_DIR="/run/user/$(id -u sunshine)"
			export WAYLAND_DISPLAY=wayland-0
			${pkgs.wlr-randr}/bin/wlr-randr --output Virtual-1 --mode "$RESOLUTION" --scale "$DISPLAY_SCALE"
		'')
		(pkgs.writeShellScriptBin "sunshine-launch" ''
			# switch user if necessary
			SUNSHINE_USER="''${SUNSHINE_USER:-$USER}"
			if test "$SUNSHINE_USER" != "$(id -nu)" ; then
				exec sudo -u "$SUNSHINE_USER" "$0" "$@"
			fi
			# forward system-wide wayland socket
			export XDG_RUNTIME_DIR="/run/user/$UID"
			export WAYLAND_DISPLAY=wayland-0
			while ! test -d "$XDG_RUNTIME_DIR" ; do sleep 1 ; done
			SUNSHINE_DIR="/run/user/$(id -u sunshine)"
			ln -sf "$SUNSHINE_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/"
			# set cursor theme for HiDPI mouse pointer
			export XCURSOR_PATH=${pkgs.adwaita-icon-theme}/share/icons
			export XCURSOR_THEME=Adwaita
			# start actual application
			exec "$@"
		'')
	];
	security.sudo.extraRules = [{
		users = [ "sunshine" ];
		runAs = "%sunshine";
		commands = [{
			command = "/run/current-system/sw/bin/sunshine-launch";
			options = [ "NOPASSWD" ];
		}];
	}];
}
