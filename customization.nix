{ lib, ... }: {
	options.customization.authorizedKey = lib.mkOption {
		type = lib.types.str;
		description = "SSH authorized key line for client login";
	};
	config.customization = {
		authorizedKey = "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
	};
}
