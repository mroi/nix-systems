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
					export XWAYLAND_HIDPI=${lib.boolToString app.xwayland-hidpi or false}
					exec sunshine-prepare
				'';
			}] ++ app.prep-cmd or [];
			xwayland-hidpi = null;
		});
		vmware = args: pkgs.writeShellScript "vmware" ''
			exec sunshine-launch ${pkgs.writeShellScript "vmware" ''
				# inject default configuration options
				if ! test -d "$HOME/.vmware" ; then
					mkdir "$HOME/.vmware"
					cat <<- EOF > "$HOME/.vmware/preferences"
						prefvmx.defaultVMPath = "/mnt/vm/$USER"
						pref.trayicon.enabled = "never"
					EOF
				fi
				# clean up window state
				sed --in-place '/^pref\.ws\.session/d' "$HOME/.vmware/preferences"
				sed --in-place '/^pref\.library\.searchMRU/d' "$HOME/.vmware/preferences"
				# symlink license file for sync and backup
				if test "$USER" = michael && test -r /etc/vmware/license-* ; then
					ln -snf /etc/vmware/license-* "/mnt/vm/$USER/"
				fi
				# launch VMware
				exec vmware ${args}
			''}
		'';
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
	in (appsForUser "michael" [
		{
			name = "VMware";
			image-path = ./vmware.png;
			cmd = vmware "";
			xwayland-hidpi = true;
		}
		{
			name = "Windows 98";
			image-path = ./windows-98.png;
			cmd = vmware "-X -q '/mnt/vm/michael/Windows 98.vmwarevm/Windows 98.vmx'";
		}
		{
			name = "Windows XP";
			image-path = ./windows-xp.png;
			cmd = vmware "-X -q '/mnt/vm/michael/Windows XP.vmwarevm/Windows XP.vmx'";
		}
		{
			name = "Windows 10";
			image-path = ./windows-10.png;
			cmd = vmware "-X -q '/mnt/vm/michael/Windows 10.vmwarevm/Windows 10.vmx'";
			xwayland-hidpi = true;
		}
	]) ++ (appsForUser "paula" [
#		{
#			name = "Windows 10";
#			image-path = ./windows-10.png;
#			cmd = vmware "-X -q '/mnt/vm/paula/Windows 10.vmwarevm/Windows 10.vmx'";
#			xwayland-hidpi = true;
#		}
	]) ++ (appsForUser "michael" unigine) ++ (appsForUser "paula" unigine);
})
