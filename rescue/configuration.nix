{ pkgs, modulesPath, ... }: {
	imports = [
		"${modulesPath}/installer/cd-dvd/iso-image.nix"
		"${modulesPath}/profiles/all-hardware.nix"
		"${modulesPath}/profiles/base.nix"
		../customization.nix
	];
	system.stateVersion = "24.05";

	networking.useDHCP = false;

	environment.systemPackages = with pkgs; [
		# convenience tools
		file
	];

	users.users.root.hashedPassword = "";
	services.getty.autologinUser = "root";
	environment.variables = { TERM = "linux"; };
	environment.shellInit = "setterm --blank=5";

	#services.avahi = {
	#	enable = true;
	#	nssmdns4 = true;
	#};

	#security.pam.services.sshd.allowNullPassword = true;
	#services.openssh = {
	#	enable = true;
	#	settings = {
	#		PermitRootLogin = "yes";
	#		PermitEmptyPasswords = "yes";
	#	};
	#};
}
