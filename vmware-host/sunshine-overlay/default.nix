self: super: {

	sunshine = super.sunshine.overrideAttrs (attrs: {
		patches = (attrs.patches or []) ++ [
			# libpulse restricts the permissions of the pulse socket directory
			# we need the socket accessible by other users, so we add g+rx
			./pulse-permissions.patch
			# use the client certificate to differentiate apps by user:
			# the sunshine state file is extended with a username field
			# the sunshine apps file is extended with a per-app user-filter field
			./user-separation.patch
		];
	});
}
