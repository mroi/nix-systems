{ lib, modulesPath, ... }: {
	imports = [
		"${modulesPath}/profiles/minimal.nix"
	];
	environment.noXlibs = false;  # set true by minimal.nix, but causes binary cache misses

	# reduce writes to the file system and enable trimming
	fileSystems."/".options = [ "noatime" ];
	fileSystems."/tmp" = {
		device = "none";
		fsType = "tmpfs";
		options = [ "mode=1777" ];
	};
	services.journald.extraConfig = "Storage=volatile";
	services.fstrim.enable = true;

	# reduce closure size: disable base CLI tools, ZFS
	disabledModules = [ "${modulesPath}/profiles/base.nix" ];
	boot.supportedFilesystems = { zfs = lib.mkForce false; };
}
