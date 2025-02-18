{ config, name, ... }: {

	# system upgrades and garbage collection
	system.autoUpgrade = {
		enable = true;
		flake = "/etc/nixos#${name}";
		operation = "boot";
		# assuming shell command substitution to run flake update before nixos-rebuild
		flags = [ "$(nix flake update --flake /etc/nixos nixpkgs)" ];
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
			"if test \"$1\" = update -o \"$1\" = all ; then " +
				"sudo nix flake update " +
					"--flake /etc/nixos " +
					"nixpkgs ; " +
				"shift ; " +
			"fi ; " +
			"sudo nixos-rebuild " +
				"--flake ${config.system.autoUpgrade.flake} " +
				"$(test $# -gt 0 || echo switch) " +
				"\"$@\" ; " +
		"} ; _rebuild";
	};
}
