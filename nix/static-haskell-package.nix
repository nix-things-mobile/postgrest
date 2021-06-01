# Derive a fully static Haskell package based on musl instead of glibc.
{ nixpkgs, compiler, patches, allOverlays }:

name: src:
let
  # The nh2/static-haskell-nix project does all the hard work for us.
  static-haskell-nix =
    let
      rev = "382150290ba43b6eb41981c1ab3b32aa31798140";
    in
    builtins.fetchTarball {
      url = "https://github.com/nh2/static-haskell-nix/archive/${rev}.tar.gz";
      sha256 = "0zsyplzf1k235rl26irm27y5ljd8ciayw80q575msxa69a9y2nvd";
    };

  patched-static-haskell-nix =
    patches.applyPatches "patched-static-haskell-nix"
      static-haskell-nix
      [
        patches.static-haskell-nix-postgrest-openssl-linking-fix
        patches.static-haskell-nix-hasql-notifications-openssl-linking-fix
      ];

  patchedNixpkgs =
    patches.applyPatches "patched-nixpkgs"
      nixpkgs
      [
        patches.nixpkgs-openssl-split-runtime-dependencies-of-static-builds
        patches.nixpkgs-gdb-fix-libintl
      ];

  extraOverrides =
    final: prev:
    rec {
      # We need to add our package needs to the package set that we pass to
      # static-haskell-nix. Using callCabal2nix on the haskellPackages that
      # it returns would result in a dynamic build based on musl, and not the
      # fully static build that we want.
      "${name}" =
        prev.callCabal2nix name src { };
    };

  overlays =
    [
      (allOverlays.haskell-packages { inherit compiler extraOverrides; })
    ];

  # Apply our overlay to the given pkgs.
  normalPkgs =
    import patchedNixpkgs { inherit overlays; };

  # Each version of GHC needs a specific version of Cabal.
  defaultCabalPackageVersionComingWithGhc =
    {
      ghc884 = "Cabal_3_2_1_0";
    }."${compiler}";

  # The static-haskell-nix 'survey' derives a full static set of Haskell
  # packages, applying fixes where necessary.
  survey =
    import "${patched-static-haskell-nix}/survey" { inherit normalPkgs compiler defaultCabalPackageVersionComingWithGhc; };
in
survey.haskellPackages."${name}"
