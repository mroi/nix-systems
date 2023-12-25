{ config, lib, pkgs }:

pkgs.writeText "apps.json" (builtins.toJSON {
	env = {
		PATH = "${config.security.wrapperDir}:/run/current-system/sw/bin";
	};
	apps = let
		users = {
			michael = { width = 5120; height = 2880; scale = 2; };
			paula = { width = 2880; height = 1800; scale = 2; };
		};
		appsForUser = user: list: lib.forEach list (app: app // {
			user-filter = user;
			auto-detach = false;
			prep-cmd = let props = lib.getAttr user users; in [{
				do = pkgs.writeShellScript "prepare" ''
					export SUNSHINE_CLIENT_WIDTH=${toString props.width}
					export SUNSHINE_CLIENT_HEIGHT=${toString props.height}
					export DISPLAY_SCALE=${toString props.scale}
					exec sunshine-prepare
				'';
			}] ++ app.prep-cmd or [];
		});
		unigine = [
			{
				name = "Heaven";
				image-path = ./heaven.png;
				cmd = pkgs.writeShellScript "heaven" ''
					exec sunshine-launch ${pkgs.unigine-heaven}/bin/heaven
				'';
			}
			{
				name = "Valley";
				image-path = ./valley.png;
				cmd = pkgs.writeShellScript "valley" ''
					exec sunshine-launch ${pkgs.unigine-valley}/bin/valley
				'';
			}
			{
				name = "Superposition";
				image-path = ./superposition.png;
				cmd = pkgs.writeShellScript "superposition" ''
					exec sunshine-launch ${pkgs.unigine-superposition}/bin/Superposition
				'';
			}
		];
	in (appsForUser "michael" unigine) ++ (appsForUser "paula" unigine);
})
