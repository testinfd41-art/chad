{ pkgs, inputs, ... }:

let
  filemQt = pkgs.buildEnv {
    name = "filem-qt-runtime";
    paths = with pkgs.qt6; [
      qtbase
      qtdeclarative
      qtmultimedia
      qtwayland
      qtsvg
    ] ++ [
      pkgs.libglvnd
    ];
    ignoreCollisions = true;
  };

  filemLauncher = pkgs.writeShellScriptBin "filem" ''
    export FILEM_QML_DIR="${inputs.filem}/qml"
    export QT_PLUGIN_PATH="${filemQt}/lib/qt-6/plugins"
    export QML2_IMPORT_PATH="${filemQt}/lib/qt-6/qml"
    export QML_IMPORT_PATH="${filemQt}/lib/qt-6/qml"
    export LD_LIBRARY_PATH="${filemQt}/lib:${pkgs.glib.out}/lib:${pkgs.stdenv.cc.cc.lib}/lib"
    export GIO_EXTRA_MODULES="${pkgs.gvfs}/lib/gio/modules"
    exec ${pkgs.stdenv.cc.bintools.dynamicLinker} \
      /home/chris/nixos-dotfiles/local/bin/filem-bin "$@"
  '';

  filemDesktop = pkgs.runCommand "filem-desktop-assets" {} ''
    install -Dm644 ${inputs.filem}/packaging/filem.desktop \
      $out/share/applications/filem.desktop
    substitute $out/share/applications/filem.desktop \
      $out/share/applications/filem.desktop.tmp \
      --replace-fail "Icon=filem" "Icon=system-file-manager"
    mv $out/share/applications/filem.desktop.tmp \
      $out/share/applications/filem.desktop
  '';
in
{
  home.packages = with pkgs; [
    filemLauncher
    filemDesktop
    filemQt
    ffmpeg
    imagemagick
    libnotify
    poppler-utils
    p7zip
    file
    exiftool
    glib.bin
    gvfs
    udisks
    systemd
    util-linux
    bzip2
    xz
    zstd
    wl-clipboard
    shared-mime-info
  ];
}
