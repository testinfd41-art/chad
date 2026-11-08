{ config, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/nixos-dotfiles/config";
  localfiles = "${config.home.homeDirectory}/nixos-dotfiles/local";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;

  configs = {
    niri = "niri";
    nvim = "nvim";
    fastfetch = "fastfetch";
    rofi = "rofi";
    foot = "foot";
  };
in

{

  imports = [
    ./modules/home
  ];


  home.username = "chris";
  home.homeDirectory = "/home/chris";
  services.udiskie = {
    enable = true;
  };
  home.stateVersion = "26.05";
  programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake ~/nixos-dotfiles#dope-nixos";
    };
    initExtra = ''
          export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
      	  export PS1="\[\e[38;5;75m\]\u@\h \[\e[38;5;113m\]\w \[\e[38;5;189m\]\$ \[\e[0m\]"
    '';
  };


  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "testinfd41-art";
        email = "testinfd41@gmail.com";
      };

      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  home.sessionPath = [
    "$HOME/.opencode/bin"
  ];
  programs.noctalia.enable = true;
  services.mpd = {
    enable = true;
    musicDirectory = "${config.home.homeDirectory}/Music";
    extraConfig = ''
      audio_output {
        type "pipewire"
        name "PipeWire"
        mixer_type "software"
      }
    '';
  };
  home.packages = with pkgs; [
    ripgrep
    nixpkgs-fmt
    jq
    nodejs
    gcc
    fzf
    nil
    fd
    git
    luau-lsp
  ];
  xdg.configFile = builtins.mapAttrs
    (name: subpath: {
      source = create_symlink "${dotfiles}/${subpath}";
      recursive = true;
    })
    configs;

  home.file.".local/bin" = {
    source = create_symlink "${localfiles}/bin/";
    recursive = true;
  };
}
