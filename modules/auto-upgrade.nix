{ config, name, ... }: {

	# system upgrades and garbage collection
	system.autoUpgrade = {
		enable = true;
		flake = "/etc/nixos#${name}";
		operation = "boot";
		flags = [ "--update-input" "nixpkgs" ];
	};
	nix = {
		channel.enable = false;
		settings.keep-build-log = false;
		settings.max-jobs = 1;
		settings.sync-before-registering = true;
		gc.automatic = true;
		gc.options = "--delete-older-than 100d";
	};
	environment.shellAliases = {
		rebuild = "_rebuild() { " +
			"if test \"$1\" = --update -o \"$1\" = -u ; then " +
				"local update='--update-input nixpkgs' ; shift ; " +
			"fi ; " +
			"sudo nixos-rebuild " +
				"--flake /etc/nixos#${name} " +
				"$update " +
				"$(test $# -gt 0 || echo switch) " +
				"\"$@\" ; " +
		"} ; _rebuild";
	};
}
