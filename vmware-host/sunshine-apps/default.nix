{ config, pkgs }:

pkgs.writeText "apps.json" (builtins.toJSON {
	env = {
		PATH = "${config.security.wrapperDir}:/run/current-system/sw/bin";
	};
	apps = [
		{
			name = "Desktop";
			image-path = "desktop.png";
		}
	];
})
