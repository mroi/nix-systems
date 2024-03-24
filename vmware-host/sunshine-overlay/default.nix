self: super: {

	# add configurable property to disable autoscaling of X11 apps on HiDPI displays
	# https://labwc.github.io/hidpi-scaling-patches.html
	# https://gitlab.freedesktop.org/xorg/xserver/-/merge_requests/733
	xwayland = super.xwayland.overrideAttrs (attrs: {
		patches = assert !(attrs ? patches); self.fetchpatch {
			url = "https://aur.archlinux.org/cgit/aur.git/plain/hidpi.patch?h=xorg-xwayland-hidpi-xprop";
			hash = "sha256-e1Yv2s9rDV5L0sVlwbsjmlgzOv8csCrPQ9aZSuZuEDQ=";
		};
	});
	wlroots_0_18 = super.wlroots_0_18.overrideAttrs (attrs: {
		patches = attrs.patches ++ [
			(self.fetchpatch {
				url = "https://gitlab.freedesktop.org/lilydjwg/wlroots/-/commit/ee299e40f24e63c23a55b4b3f7fcc52c15205092.patch";
				hash = "sha256-860NqAM7tTIy1nKtYocvglxizt/S0v+KLOe7iNHhaps=";
			})
			(self.fetchpatch {
				url = "https://aur.archlinux.org/cgit/aur.git/plain/0003-Fix-size-hints-under-Xwayland-scaling.patch?h=wlroots-hidpi-xprop-git";
				hash = "sha256-vCI01bHGFONzYVTJIXBJenHgC5Q65GYotjuWhoIY0lk=";
			})
		];
	});
	labwc = assert self.lib.any (x: x.name == self.xwayland.name) super.labwc.buildInputs;
		assert self.lib.any (x: x.name == self.wlroots_0_18.name) super.labwc.buildInputs;
		super.labwc;

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
