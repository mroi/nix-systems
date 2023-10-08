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

	config.console.keyMap = "de";
	config.time.timeZone = "Europe/Berlin";
}
