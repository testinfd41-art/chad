{ config, lib, pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "dope-nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Kolkata";

  services.flatpak.enable = true;
  nixpkgs.config.allowUnfree = true;
  services.displayManager.ly.enable = true;
  programs.niri.enable = true;

  zramSwap = {
    enable = true;
    priority = 100;
    algorithm = "lz4";
    memoryPercent = 75;
  };

  users.users.chris = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  hardware.graphics.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  hardware.i2c.enable = true;
  hardware.i2c.group = "i2c";
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;
  programs.nix-ld.enable = true;


  security = {
    polkit.enable = true;
    rtkit.enable = true;
  };

  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
  };

  environment.systemPackages = with pkgs; [
    neovim
    git
    foot
    btop
    htop
    yazi
    fastfetch
    pulseaudio
    pavucontrol
    libnotify
    libva-utils
    mpv
    brightnessctl
    papirus-icon-theme
    xwayland-satellite
    ffmpegthumbnailer
    ddcutil
    playerctl
    imagemagick
    nvd
    unzip
    gnome-software
    nautilus
    evince
    loupe
    wl-clipboard
    yt-dlp
    ffmpeg
    obs-studio
    rmpc
    pdfarranger
    zenity
    zed-editor
    kdlfmt
    stylua
    lxmenu-data
    shared-mime-info
    poppler-utils
  ];

  programs.localsend.enable = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    ubuntu-sans
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}

