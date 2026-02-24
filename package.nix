{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  glibc,
}:
let
  currentVersion = lib.importJSON ./version.json;
  downloadUrl =
    platform:
    "https://github.com/github/copilot-cli/releases/download/v${currentVersion.version}/copilot-${platform}.tar.gz";
  defaultArgs =
    {
      "x86_64-linux" = {
        src = fetchurl {
          url = downloadUrl "linux-x64";
          hash = currentVersion."hash-linux-x64";
        };
      };
      "aarch64-linux" = {
        src = fetchurl {
          url = downloadUrl "linux-arm64";
          hash = currentVersion."hash-linux-arm64";
        };
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "github-copilot-cli-bin: Unsupported platform: ${stdenv.hostPlatform.system}");
  ldLibraryPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    glibc
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "github-copilot-cli-bin";
  version = currentVersion.version;
  inherit (defaultArgs) src;

  nativeBuildInputs = [
    makeWrapper
  ];

  sourceRoot = ".";

  dontBuild = true;
  dontConfigure = true;
  noDumpEnvVars = true;
  dontPatchELF = true;
  dontAutoPatchelf = true;
  dontStrip = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    install -m 755 copilot $out/lib/copilot
    makeWrapper $out/lib/copilot $out/bin/copilot \
      --prefix LD_LIBRARY_PATH : "${ldLibraryPath}"
    runHook postInstall
  '';

  meta = {
    description = "GitHub Copilot CLI";
    homepage = "https://github.com/github/copilot-cli";
    license = lib.licenses.unfreeRedistributable;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = "copilot";
  };
})
