{ lib, modulesPath, ... }: {
	imports = [
		"${modulesPath}/profiles/minimal.nix"
	];

	# reduce writes to the file system and enable trimming
	fileSystems."/".options = [ "noatime" ];
	fileSystems."/tmp" = {
		device = "none";
		fsType = "tmpfs";
		options = [ "mode=1777" ];
	};
	nix.settings.auto-optimise-store = true;
	services.journald.extraConfig = "Storage=volatile";
	services.fstrim.enable = true;

	# reduce closure size: do not keep Nixpkgs source tree or build dependencies
	nix.registry = lib.mkForce {};
	nix.settings.keep-derivations = false;

	# reduce closure size: disable base CLI tools, ZFS
	disabledModules = [ "${modulesPath}/profiles/base.nix" ];
	boot.supportedFilesystems = { zfs = lib.mkForce false; };
}
