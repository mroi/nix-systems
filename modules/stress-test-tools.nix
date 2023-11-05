{ config, pkgs, ... }: {

	# enable memtest
	nixpkgs.config.allowUnfree = true;
	boot.loader.grub.memtest86.enable = true;

	# enable CUDA
	boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11.bin ];
	hardware.opengl.extraPackages = [ config.boot.kernelPackages.nvidia_x11.out ];
	hardware.opengl.enable = true;
	hardware.nvidia.open = true;

	environment.systemPackages =
		let gpu-burn = pkgs.gpu-burn.overrideAttrs (attrs: {
			# gpu_burn internally launches nvidia-smi, which is not found in PATH
			nativeBuildInputs = attrs.nativeBuildInputs ++ [ pkgs.makeWrapper ];
			postFixup = attrs.postFixup + ''
				wrapProgram $out/bin/gpu_burn \
					--prefix PATH : ${config.boot.kernelPackages.nvidia_x11.bin}/bin
			'';
		});
		in [ pkgs.stress pkgs.s-tui gpu-burn ];
}
