{ config, ... }: {

	# system upgrades and garbage collection
	system.autoUpgrade = {
		enable = true;
		operation = "boot";
		channel = config.system.defaultChannel;
	};
	nix = {
		settings.keep-build-log = false;
		settings.max-jobs = 1;
		gc.automatic = true;
		gc.options = "--delete-older-than 100d";
	};
}
