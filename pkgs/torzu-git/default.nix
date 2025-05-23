{
  current,

  lib,
  stdenv,
  wrapQtAppsHook,
  alsa-lib,
  boost187,
  catch2_3,
  cmake,
  cpp-jwt,
  cubeb,
  discord-rpc,
  doxygen,
  enet,
  fetchTorGit,
  fetchurl,
  fetchzip,
  ffmpeg,
  fmt_11,
  glslang,
  httplib,
  inih,
  libjack2,
  libopus,
  libpulseaudio,
  libusb1,
  libva,
  libzip,
  lz4,
  nlohmann_json,
  perl,
  pkg-config,
  python3,
  qtbase,
  qtmultimedia,
  qttools,
  qtwayland,
  qtwebengine,
  rapidjson,
  SDL2,
  sndio,
  speexdsp,
  udev,
  vulkan-loader,
  zlib,
  zstd,
}:

let
  compat-list =
    with current.compatList;
    fetchurl {
      name = "yuzu-compat-list";
      url = "https://raw.githubusercontent.com/flathub/org.yuzu_emu.yuzu/${rev}/compatibility_list.json";
      inherit hash;
    };

  tzinfo =
    with current.tzinfo;
    fetchzip {
      url = "https://github.com/lat9nq/tzdb_to_nx/releases/download/${version}/${version}.zip";
      stripRoot = false;
      inherit hash;
    };
in
stdenv.mkDerivation {
  pname = "torzu";

  inherit (current) version;

  src = fetchTorGit {
    url = "http://vub63vv26q6v27xzv2dtcd25xumubshogm67yrpaz2rculqxs7jlfqad.onion/torzu-emu/torzu.git";
    fetchSubmodules = true;
    inherit (current) rev hash;
  };

  nativeBuildInputs = [
    cmake
    doxygen
    perl
    pkg-config
    python3
    wrapQtAppsHook
  ];

  buildInputs = [
    alsa-lib
    boost187
    catch2_3
    cpp-jwt
    cubeb
    discord-rpc
    # intentionally omitted: dynarmic - prefer vendored version for compatibility
    enet
    ffmpeg
    fmt_11
    glslang
    httplib
    inih
    libjack2
    libopus
    libpulseaudio
    libusb1
    libva
    libzip
    # intentionally omitted: LLVM - heavy, only used for stack traces in the debugger
    lz4
    nlohmann_json
    qtbase
    qtmultimedia
    qttools
    qtwayland
    qtwebengine
    rapidjson
    SDL2
    sndio
    speexdsp
    udev
    # intentionally omitted: xbyak - prefer vendored version for compatibility
    zlib
    zstd
  ];

  # This changes `ir/opt` to `ir/var/empty` in `externals/dynarmic/src/dynarmic/CMakeLists.txt`
  # making the build fail, as that path does not exist
  dontFixCmake = true;

  cmakeFlags = [
    # actually has a noticeable performance impact
    "-DYUZU_ENABLE_LTO=ON"

    # build with qt6
    "-DENABLE_QT6=ON"
    "-DENABLE_QT_TRANSLATION=ON"

    # use system libraries
    "-DYUZU_USE_EXTERNAL_SDL2=OFF"

    # don't check for missing submodules
    "-DYUZU_CHECK_SUBMODULES=OFF"

    # enable some optional features
    "-DYUZU_USE_QT_WEB_ENGINE=ON"
    "-DYUZU_USE_QT_MULTIMEDIA=ON"
    "-DUSE_DISCORD_PRESENCE=ON"

    # We dont want to bother upstream with potentially outdated compat reports
    "-DYUZU_ENABLE_COMPATIBILITY_REPORTING=OFF"
    "-DENABLE_COMPATIBILITY_LIST_DOWNLOAD=OFF" # We provide this deterministically
  ];

  # Fixes vulkan detection.
  # FIXME: patchelf --add-rpath corrupts the binary for some reason, investigate
  qtWrapperArgs = [
    "--prefix LD_LIBRARY_PATH : ${vulkan-loader}/lib"
  ];

  preConfigure = ''
    # see https://github.com/NixOS/nixpkgs/issues/114044, setting this through cmakeFlags does not work.
    cmakeFlagsArray+=(
      "-DTITLE_BAR_FORMAT_IDLE=torzu | git ${current.version} (chaotic-nyx) {}"
      "-DTITLE_BAR_FORMAT_RUNNING=torzu | git ${current.version} (chaotic-nyx) | {}"
    )

    # provide pre-downloaded tz data
    mkdir -p build/externals/nx_tzdb
    ln -sf ${tzinfo} build/externals/nx_tzdb/nx_tzdb
  '';

  # This must be done after cmake finishes as it overwrites the file
  postConfigure = ''
    ln -sf ${compat-list} ./dist/compatibility_list/compatibility_list.json
  '';

  doCheck = false;

  env.SOURCE_DATE_EPOCH = current.lastModified;

  meta = with lib; {
    homepage = "http://vub63vv26q6v27xzv2dtcd25xumubshogm67yrpaz2rculqxs7jlfqad.onion/torzu-emu/torzu";
    description = "The TOR branch of an experimental Nintendo Switch emulator written in C++";
    longDescription = ''
      An experimental Nintendo Switch emulator written in C++.
      Using the mainline branch is recommended for general usage.
      Using the early-access branch is recommended if you would like to try out experimental features, with a cost of stability.
    '';
    mainProgram = "yuzu";
    platforms = [ "x86_64-linux" ];
    license = with licenses; [
      gpl3Plus
      # Icons
      asl20
      mit
      cc0
    ];
    maintainers = with maintainers; [
      ashley
      ivar
      joshuafern
      sbruder
      k900
    ];
  };
}
