{ config, lib, pkgs, raspberry, ... }: {
	imports = [ raspberry.nixosModules.raspberry-pi ];
}
