# Fixed-output, since scaffolding runs `go mod tidy` and `go install`s the tools the generated Makefile pins.
{
  lib,
  stdenvNoCC,
  bash,
  cacert,
  git,
  gnumake,
  go,
  kubebuilder,
}:
{
  name ? "kubebuilder-scaffold",
  src,
  hash ? lib.fakeHash,
}:
stdenvNoCC.mkDerivation {
  inherit name src;

  nativeBuildInputs = [
    git
    gnumake
    go
    kubebuilder
  ];

  env = {
    CGO_ENABLED = "0";
    GOTOOLCHAIN = "local";
    GOFLAGS = "-mod=mod";
    GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    # The sandbox has no /usr/bin/env, and LOCALBIN keeps the installed tools out of the output.
    MAKEFLAGS = "SHELL=${lib.getExe bash} LOCALBIN=/build/tools";
  };

  dontConfigure = true;
  dontFixup = true;

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR/home
    export GOPATH=$TMPDIR/go
    export GOCACHE=$TMPDIR/go-cache

    kubebuilder alpha generate --input-dir . --output-dir $TMPDIR/out

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    cp -r $TMPDIR/out $out

    runHook postInstall
  '';

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = hash;
}
