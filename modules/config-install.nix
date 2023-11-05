{ config, pkgs, lib, ... }:

let
	folder = config.nix.configFolderName;
	configFiles = import ./config-build.nix {
		inherit pkgs folder;
	};

in {
	options.nix.configFolderName = lib.mkOption {
		type = lib.types.str;
		description = "folder name containing the main configuration.nix, will be installed in /etc/nixos";
	};
	
	config.boot.postBootCommands = ''
		# install system configuration
		if ! test -f /etc/nixos/configuration.nix ; then
			cat > /etc/nixos/configuration.nix <<- 'EOF'
				{ ... }: {
					imports = [
						${configFiles}/${folder}/configuration.nix
					];
				}
			EOF
		fi
	'';
}
