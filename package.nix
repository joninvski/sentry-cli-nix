{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs_22,
}:

stdenvNoCC.mkDerivation rec {
  pname = "sentry";
  version = "0.49.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/sentry/-/sentry-${version}.tgz";
    hash = "sha256-TAmQspVZqJUz6y5qeDpetbuaCC/35foK1dpEHdCbMIo=";
  };

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/sentry" "$out/bin"
    cp -R . "$out/lib/sentry/"
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/sentry" \
      --add-flags "$out/lib/sentry/dist/bin.cjs"
    runHook postInstall
  '';

  meta = {
    description = "Command-line interface for using Sentry, for humans and agents";
    homepage = "https://cli.sentry.dev";
    changelog = "https://github.com/getsentry/toolkit/releases";
    license =
      lib.licenses.fsl11Asl20 or {
        shortName = "FSL-1.1-Apache-2.0";
        fullName = "Functional Source License, Version 1.1, Apache 2.0 Future License";
        url = "https://github.com/getsentry/toolkit/blob/main/LICENSE.md";
        free = false;
        redistributable = true;
      };
    mainProgram = "sentry";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
}
