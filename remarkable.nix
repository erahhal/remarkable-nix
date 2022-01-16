{ stdenv
, lib
, builtins
, mkWindowsApp
, wine
, fetchurl
, makeDesktopItem
, makeDesktopIcon   # This comes with erosanix. It's a handy way to generate desktop icons.
, copyDesktopItems
, copyDesktopIcons  # This comes with erosanix. It's a handy way to generate desktop icons.
, unzip }:

let
  reg_entries = builtins.readFile ./logpixels.reg;
in
mkWindowsApp rec {
  inherit wine;

  pname = "remarkable";
  version = "2.11.0.182";

  src = fetchurl {
    url = "https://downloads.remarkable.com/desktop/production/win/reMarkable-${version}-win32.exe";
    sha256 = "0yff44mb2m6yz2ip92f21gkdm7jwjl70pc6i4qhm2m9azp00m20i";
  };

  # In most cases, you'll either be using an .exe or .zip as the src.
  # Even in the case of a .zip, you probably want to unpack with the launcher script.
  dontUnpack = true;   

  # You need to set the WINEARCH, which can be either "win32" or "win64".
  # Note that the wine package you choose must be compatible with the Wine architecture.
  wineArch = "win64";

  nativeBuildInputs = [ copyDesktopItems copyDesktopIcons ];

  # This code will become part of the launcher script.
  # It will execute if the application needs to be installed,
  # which would happen either if the needed app layer doesn't exist,
  # or for some reason the needed Windows layer is missing, which would
  # invalidate the app layer.
  # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
  # and wine, winetricks, and cabextract are in the environment.
  winAppInstall = ''
    cat > ./logpixels.reg<< EOF
${reg_entries}
EOF
    regedit ./logpixels.reg 
    wine ${src}
  '';

  # This code will become part of the launcher script.
  # It will execute after winAppInstall (if needed)
  # to run the application.
  # WINEPREFIX, WINEARCH, AND WINEDLLOVERRIDES are set
  # and wine, winetricks, and cabextract are in the environment.
  # Command line arguments are in $ARGS, not $@
  # You need to set up symlinks for any files/directories that need to be persisted.
  # To figure out what needs to be persisted, take at look at $(dirname $WINEPREFIX)/upper
  winAppRun = ''
    cat > ./logpixels.reg<< EOF
${reg_entries}
EOF
    # Set DPI to 0x80/128 (might be able to go a bit higher).
    regedit ./logpixels.reg 

    # Persistence path
    cache_dir="$HOME/.cache/remarkable"
    mkdir -p "$cache_dir/data/desktop"
    mkdir -p "$cache_dir/local/desktop"
    mkdir -p "$cache_dir/upper_dir"
    data_dir="$WINEPREFIX/drive_c/users/$USER/Application Data/remarkable"
    local_dir="$WINEPREFIX/drive_c/users/$USER/Local Settings/Application Data/remarkable"
    upper_dir="$WINEPREFIX/../upper_dir"
    ln -sf "$cache_dir/data" "$data_dir" 
    ln -sf "$cache_dir/local" "$local_dir" 
    ln -sf "$cache_dir/upper_dir" "$upper_dir" 

    # Run app
    binpath="$WINEPREFIX/drive_c/Program Files (x86)/reMarkable"
    wine "$binpath/reMarkable.exe" "$ARGS"
  '';

  # This is a normal mkDerivation installPhase, with some caveats.
  # The launcher script will be installed at $out/bin/.launcher
  # DO NOT DELETE OR RENAME the launcher. Instead, link to it as shown.
  installPhase = ''
    runHook preInstall

    ln -s $out/bin/.launcher $out/bin/${pname}

    runHook postInstall
  '';

  desktopItems = let
    mimeType = builtins.concatStringsSep ";" [ 
                 "application/pdf"
                 "application/epub+zip"
               ];
  in [
    (makeDesktopItem {
      inherit mimeType;

      name = pname;
      exec = pname;
      icon = pname;
      desktopName = "Remarkable 2";
      genericName = "eInk Tablet App";
      categories = "Office;Graphics;Viewer;";
    })
  ];

  desktopIcon = makeDesktopIcon {
    name = "remarkable";

    src = fetchurl {
      url = "https://preview.redd.it/r6poix54d5x41.png?width=256&format=png&auto=webp&s=d0e6abf805d34f74cdb2a7f461d6537c811a3344";
      sha256 = "16s6hxblzv8j6ymkc342rwpnhyvcdfyy5k2xr81csw8q4k4r4imd";
      name = "remarkable.png";
    };
  };

  meta = with lib; {
    description = "Desktop app for interfacing with Remarkable 2 Tablet";
    homepage = "https://remarkable.com/";
    license = licenses.unfree;
    maintainers = with maintainers; [ erahhal ];
    platforms = [ "x86_64-linux" ];
  };
}
