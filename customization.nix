{ lib, ... }: {
	options.customization.authorizedKey = lib.mkOption {
		type = lib.types.str;
		description = "SSH authorized key line for client login";
	};
	options.customization.wifi.ssid = lib.mkOption {
		type = lib.types.str;
		description = "WiFi network SSID";
	};
	options.customization.wifi.password = lib.mkOption {
		type = lib.types.str;
		description = "WiFi network password (pre-shared secret)";
	};

	config.customization = {
		authorizedKey = "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
		wifi.ssid = "";
		wifi.password = "";
	};

	config = {
		# basic system settings
		console.keyMap = "de";
		time.timeZone = "Europe/Berlin";

		# command line environment
		nix = {
			nixPath = [ "nixpkgs=flake:nixpkgs" ];
			settings.extra-experimental-features = [ "flakes" "nix-command" ];
			extraOptions = "use-xdg-base-directories = true";
		};
		programs.bash.promptInit = ''
			if test "$SSH_CLIENT" || test "$SSH2_CLIENT" ; then
				SHELL_PROMPTCOLOR=''${SHELL_PROMPTCOLOR:-2}
			fi
			if test "''${TERM#screen}" != "$TERM" ; then
				SHELL_PROMPTCOLOR=5
			fi
			if test "$SHLVL" -gt 1 ; then
				SHELL_PROMPTCOLOR=3
			fi
			if test "$USER" = root ; then
				SHELL_PROMPTCOLOR=1
			fi
			export SHELL_PROMPTCOLOR=''${SHELL_PROMPTCOLOR:-6}
			export PS1='\n\[\033[1m\033[3'$SHELL_PROMPTCOLOR'm\]\u@\h:\w > \[\033[m\]'
			export PS2='\[\033[1m\033[3'$SHELL_PROMPTCOLOR'm\]> \[\033[m\]'
			export PS4='\[\033[1m\033[3'$SHELL_PROMPTCOLOR'm\]+ \[\033[m\]'
		'';
		programs.less.envVariables = {
			LESS = "-M -I -S -R";
			LESSHISTFILE = "-";
		};
		environment.shellAliases = {
			".." = "cd ..";
			"..." = "cd ../..";
			la = "ls -al";
			pico = "nano -wL";
		};
		environment.variables = {
			HISTFILE = "";
			LC_COLLATE = "POSIX";
		};
	};
}
