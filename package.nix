# Wayseer as served: the release's Linux tarball kept byte for byte in libexec/wayseer, and a
# wrapper that runs it through nixpkgs' glibc loader. Nothing in the tarball is patched.
{ lib, stdenvNoCC, runtimeShell, glibc, src, version
, wayland, libxkbcommon, libdecor, libdrm, libgbm, libGL, vulkan-loader
, libx11, libxext, libxrandr, libxcursor, libxi, libxscrnsaver, libxtst, libxfixes
}:

let
  # The libraries SDL3 opens by name.
  windowing = [
    wayland libxkbcommon libdecor libdrm libgbm libGL vulkan-loader
    libx11 libxext libxrandr libxcursor libxi libxscrnsaver libxtst libxfixes
  ];
in
stdenvNoCC.mkDerivation {
  pname = "wayseer";
  inherit version src;

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true; # no patchelf, strip or shebang rewriting: the bytes stay the signed ones

  installPhase = ''
    runHook preInstall
    # 0.27.1 and older keep the app in bin/, where it takes the loader for itself.
    if [ ! -f lib/wayseer/wayseer ]; then
      echo "Wayseer $version predates the layout this package runs (0.27.2)" >&2
      exit 1
    fi
    copy=$out/libexec/wayseer
    mkdir -p $out/libexec $out/bin
    cp -a . $copy
    # Tells the app Nix installed it, so it never updates itself and notices point here.
    install -Dm644 /dev/stdin $copy/share/wayseer/installed-by <<< Nix
    substitute ${./wrapper.sh} $out/bin/wayseer \
      --subst-var-by shell ${runtimeShell} \
      --subst-var-by loader ${glibc}/lib/ld-linux-x86-64.so.2 \
      --subst-var-by libs ${lib.makeLibraryPath windowing} \
      --subst-var-by copy $copy
    chmod 755 $out/bin/wayseer
    mkdir -p $out/share
    ln -s $copy/share/applications $copy/share/icons $copy/share/licenses $out/share/
    runHook postInstall
  '';

  meta = {
    description = "Navigate systems data as one world you can move through";
    homepage = "https://wayseer.app";
    # The app's own terms; this flake itself is MIT.
    license = {
      shortName = "wayseer-eula";
      fullName = "Wayseer end-user license";
      url = "https://wayseer.app/license";
      free = false;
      redistributable = false;
    };
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "wayseer";
    platforms = [ "x86_64-linux" ];
  };
}
