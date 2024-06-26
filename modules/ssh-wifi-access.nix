{ config, lib, ... }: {

	# configure basic network services
	networking.wireless = {
		enable = true;
		networks.${config.customization.wifi.ssid}.psk = config.customization.wifi.password;
	};
	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "yes";
			PasswordAuthentication = false;
			KbdInteractiveAuthentication = false;
		};
	};
	users.users.root.openssh.authorizedKeys.keys = [
		config.customization.authorizedKey
	];
	services.avahi = {
		enable = true;
		publish.enable = true;
		publish.userServices = true;
		extraServiceFiles.ssh = let
			capitalizedHostName =
				(lib.toUpper (lib.substring 0 1 config.networking.hostName)) +
				(lib.toLower (lib.substring 1 (-1) config.networking.hostName));
		in ''<?xml version="1.0" standalone='no'?>
			<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
			<service-group>
				<name>${capitalizedHostName}</name>
				<service>
					<type>_ssh._tcp</type>
					<port>22</port>
				</service>
			</service-group>
		'';
	};
}
