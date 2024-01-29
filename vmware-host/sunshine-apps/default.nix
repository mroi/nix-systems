{ config, pkgs }:

pkgs.writeText "apps.json" (builtins.toJSON {
	env = {
		PATH = "${config.security.wrapperDir}:/run/current-system/sw/bin";
	};
	apps = [
		{
			name = "Desktop";
			image-path = "desktop.png";
			prep-cmd = [{ do = pkgs.writeShellScript "prepare" ''
				export SUNSHINE_CLIENT_WIDTH=5120
				export SUNSHINE_CLIENT_HEIGHT=2880
				exec sunshine-prepare
			''; }];
		}
	];
})
