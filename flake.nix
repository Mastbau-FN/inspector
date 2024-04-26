{
  description = "Flutter Inspection App";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        frontend-dir = ./frontend;
        pkg-opts = {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };
        pkgs-unstable = import nixpkgs { inherit (pkg-opts) system config;};
        pkgs = import nixpkgs-stable { inherit (pkg-opts) system config; };
      in rec {

        deps = with pkgs; [
          flutter
          git
        ];

        android-data = {
          abiVersion = "arm64-v8a";
          platformVersion = "34";
        };

        android = pkgs.androidenv.composeAndroidPackages {
          toolsVersion = "26.1.1";
          platformToolsVersion = "34.0.5";
          buildToolsVersions = [ "30.0.0"  "30.0.3" "31.0.0" ];
          includeEmulator = true;
          emulatorVersion = "34.1.9";
          platformVersions = [ "31" "33" "34" android-data.platformVersion ];
          includeSources = false;
          includeSystemImages = true;
          systemImageTypes = [ "google_apis_playstore" ];
          abiVersions = [ "x86_64" "armeabi-v7a" "arm64-v8a" android-data.abiVersion ];
          cmakeVersions = [ "3.10.2" "3.18.1" ];
          includeNDK = true;
          ndkVersions = [ "23.1.7779620" "22.0.7026061" ];
          useGoogleAPIs = false;
          useGoogleTVAddOns = false;
          #avdmanager
          extraLicenses = [
              "android-sdk-preview-license"
              "android-googletv-license"
              "android-sdk-arm-dbt-license"
              "google-gdk-license"
              "intel-android-extra-license"
              "intel-android-sysimage-license"
              "mips-android-sysimage-license"
            ];
          # extras = ["extras;google;gcm"];
        };

        packages = {
          apk = pkgs.stdenv.mkDerivation {
            name = "apk";
            buildInputs = with pkgs; deps ++ [ jdk17 android.androidsdk ];
            src = frontend-dir;
            buildPhase = ''
              flutter build apk
            '';
            # TODO: install st that nix run .#apk opens avd
          };
          # aab = pkgs.stdenv.mkDerivation {
          #   name = "aab";
          #   buildInputs = with pkgs; deps ++ [ jdk17 android ];
          #   buildPhase = ''
          #     flutter build aab
          #   '';
          # };



          linux = pkgs.stdenv.mkDerivation {
            name = "linux binary executable";
            src = frontend-dir;
            buildInputs = with pkgs; deps ++ [  ];
            buildPhase = ''
              flutter build linux
            '';
          };
        };

        defaultPackage = packages.apk;

        # shell = mkShell

        # devShells.default =
        #   let 
        #     java = pkgs.jdk17;
        #     android = pkgs-stable.callPackage ./nix/android.nix { };
        #   in pkgs.mkShell {
        #     buildInputs = with pkgs; [
        #       git 

        #       #  myflutter 
        #       # (flutter.override { channel = "master"; })
        #       flutter

        #       # flutter web:
        #       google-chrome

        #       # java and android
        #       java
        #       #  glibc
        #       android.androidsdk
        #       # android-studio #prinzipiell nicht nötig wenn avdmanager läuft

        #       # linux 
        #       clang
        #       cmake
        #       ninja
        #       pkg-config
        #       # gtk3
        #       # pkgs-stable.glib
        #       # pkgs-stable.pcre.dev
        #       libepoxy.dev
        #       # needed for linux video player (FVP) --doenst work yet 
        #       # libdrm
        #       # libGL
        #       #  alsa-lib
        #       #  pulseaudio
        #       #  mesa
        #       #  xorg.libX11
        #       # instead of fvp, use media_kit, it needs:
        #       # mympv
        #       # libass #subtitles
        #       # libsecret
        #       # pcre.dev

        #       # backend
        #       docker
        #       supabase-cli
        #     ];

        #     ANDROID_HOME = "${android.androidsdk}/libexec/android-sdk";
        #     JAVA_HOME = java;
        #     ANDROID_AVD_HOME = (toString ./.) + "/.android/avd";
        #     #  ANDROID_AVD_HOME = "$HOME/.config/.android/avd";
        #     ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
        #     GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${android.androidsdk}/libexec/android-sdk/build-tools/31.0.0/aapt2";
        #     CHROME_EXECUTABLE = "${pkgs.google-chrome}/bin/google-chrome-stable";

        #     #  LD_LIBRARY_PATH= "${pkgs.alsa-lib}/lib:${pkgs.libdrm}/lib:${pkgs.libGL}/lib:${pkgs.libepoxy}/lib:${pkgs.pulseaudio}/lib:${pkgs.mesa}/lib:${pkgs.xorg.libX11}/lib:$LD_LIBRARY_PATH";
        #     # LD_LIBRARY_PATH= "$LD_LIBRARY_PATH"; #for media kit linux build

        #     #  PATH = "$PATH:${pkgs.flutter}/bin/cache/dart-sdk";
        #     FLUTTER_ROOT = "${pkgs.flutter}";

        #     #  LD_LIBRARY_PATH= "${libepoxy}/lib";
          
        #       # yes | flutter doctor --android-licenses
        #     shellHook = ''
        #       export PATH=$PATH:${pkgs.flutter}/bin/cache/dart-sdk/bin
        #       alias release='git checkout staging && git rebase main && git push && git checkout main'
        #       # ./backend/start.dev.sh # start backend
        #       # trap "backend/stop.dev.sh" EXIT # stop backend 
        #       # zsh
        #       # code .
        #       # $SHELL
        #       export PATH=$PATH:scripts
        #     '';
        #   };
      });
}
