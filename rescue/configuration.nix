{ pkgs, modulesPath, ... }: {
	imports = [
		"${modulesPath}/installer/cd-dvd/iso-image.nix"
		"${modulesPath}/profiles/all-hardware.nix"
		"${modulesPath}/profiles/base.nix"
		../customization.nix
	];
	system.stateVersion = "23.11";

	networking.useDHCP = false;

	environment.systemPackages = with pkgs; [
		# convenience tools
		file
	];

	environment.variables = {
		TERM = "vt220";
	};
	services.getty.autologinUser = "root";
}
