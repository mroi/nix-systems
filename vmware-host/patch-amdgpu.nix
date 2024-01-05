{ pkgs, lib, kernel ? pkgs.linuxPackages.kernel }:

pkgs.stdenv.mkDerivation {
	pname = "amdgpu-module";
	inherit (kernel) src version postPatch nativeBuildInputs;

	makeFlags = [
		"M=drivers/gpu/drm/amd/amdgpu"
		"INSTALL_MOD_PATH=${placeholder "out"}"
	];

	patches = pkgs.writeText "amdgpu-resolutions.patch" ''
		--- a/drivers/gpu/drm/amd/amdgpu/amdgpu_vkms.c	2023-12-25 20:56:46.298946129 +0100
		+++ b/drivers/gpu/drm/amd/amdgpu/amdgpu_vkms.c	2023-12-25 20:57:26.718645004 +0100
		@@ -231,10 +231,12 @@
		 		{1920, 1080},
		 		{1920, 1200},
		 		{2560, 1440},
		+		{2880, 1800},
		 		{4096, 3112},
		 		{3656, 2664},
		 		{3840, 2160},
		 		{4096, 2160},
		+		{5120, 2880},
		 	};
		 
		 	for (i = 0; i < ARRAY_SIZE(common_modes); i++) {
	'';

	preBuild = ''
		cp ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/Module.symvers .
		cp ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/.config .
		cp ${kernel.dev}/vmlinux .
		make modules_prepare
	'';
	buildFlags = [ "modules" ];
	installTargets = [ "modules_install" ];
}
