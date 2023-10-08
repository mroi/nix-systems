{ nixpkgs, system }:

let
	configuration = { pkgs, modulesPath, ... }: {
		imports = [
			./configuration.nix
			"${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
		];
		sdImage = {
			imageBaseName = builtins.baseNameOf ./.;
			compressImage = false;
		};
		boot.postBootCommands =
			let
				folder = builtins.baseNameOf ./.;
				configFiles = pkgs.stdenvNoCC.mkDerivation {
					name = "configuration";
					src = ./..;
					phases = [ "unpackPhase" "installPhase" ];
					installPhase = ''
						mkdir $out
						cp -r $src/${folder} $out/
						cp $src/customization.nix $out/
					'';
				};
			in ''
				# install system configuration
				if ! test -f /etc/nixos/configuration.nix ; then
					cat > /etc/nixos/configuration.nix <<- 'EOF'
						{ modulesPath, ... }: {
							imports = [
								${configFiles}/${folder}/configuration.nix
								"''${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
							];
						}
					EOF
				fi
			'';
	};

	nixos = nixpkgs.lib.nixosSystem {
		system = "aarch64-linux";
		modules = [ configuration ];
	};

in nixos.config.system.build.sdImage
