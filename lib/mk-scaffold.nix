# Build the scaffold that `kubebuilder alpha generate` produces for a PROJECT
# file.
#
# Scaffolding runs `go mod tidy`, `go get`, and `go install` for the tools the
# generated Makefile pins, so this is a fixed-output
# derivation and the caller supplies `hash`, the same way `vendorHash` works
# for `buildGoModule`.
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

    # The generated Makefile sets `SHELL = /usr/bin/env bash`, which does not
    # exist in the build sandbox. Its tools are `go install`ed at the versions
    # it pins, into a LOCALBIN kept out of the output.
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
