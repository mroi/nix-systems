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
			extraGroups = [ "wheel" "sunshine" ];
			openssh.authorizedKeys.keys = [
				config.customization.authorizedKey
			];
		};
		paula = {
			isNormalUser = true;
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
			mkdir --parents --mode=700 "$HOME/.config/sunshine"
			if ! test -f "$HOME/.config/sunshine/apps.json" ; then
				cat <<- 'EOF' > "$HOME/.config/sunshine/apps.json"
					{
					  "env": {
					    "PATH": "$(PATH)"
					  },
					  "apps": [
					    {
					      "name": "Desktop",
					      "image-path": "desktop.png"
					    }
					  ]
					}
				EOF
			fi
			ln -snf ../../sunshine.json "$HOME/.config/sunshine/sunshine_state.json"
			# prepare runtime dir so other users can access wayland socket
			export XDG_RUNTIME_DIR="/run/user/$UID"
			chmod 750 "$XDG_RUNTIME_DIR"
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
}
