{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  patchelf,
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
  runtimeLibraryPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    glibc
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "github-copilot-cli-bin";
  version = currentVersion.version;
  inherit (defaultArgs) src;

  nativeBuildInputs = [
    installShellFiles
    patchelf
  ];

  sourceRoot = ".";

  dontBuild = true;
  dontConfigure = true;
  noDumpEnvVars = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    install -m 755 copilot $out/lib/copilot

    # Patch the generic Linux release to use Nix's dynamic linker and runtime libraries.
    patchelf \
      --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
      --set-rpath "${runtimeLibraryPath}" \
      $out/lib/copilot
    ln -s ../lib/copilot $out/bin/copilot

    # Generate and install shell completions
    if $out/bin/copilot completion bash > copilot.bash 2>/dev/null; then
      installShellCompletion --bash --name copilot.bash copilot.bash
    fi
    if $out/bin/copilot completion zsh > _copilot 2>/dev/null; then
      installShellCompletion --zsh --name _copilot _copilot
    fi
    if $out/bin/copilot completion fish > copilot.fish 2>/dev/null; then
      installShellCompletion --fish --name copilot.fish copilot.fish
    fi

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
