self: super: {

	sunshine = super.sunshine.overrideAttrs (attrs: {
		patches = (attrs.patches or []) ++ [
			# libpulse restricts the permissions of the pulse socket directory
			# we need the socket accessible by other users, so we add g+rx
			./pulse-permissions.patch
		];
	});
}
