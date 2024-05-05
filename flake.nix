{
  description = "Flutter Inspection App";

  inputs = {
    # nixpkgs.url = "github:HannesGitH/nixpkgs/hannes_custom";
    nixpkgs.url = "github:nixos/nixpkgs/cf8cc1201be8bc71b7cbbbdaf349b22f4f99c7ae";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, flake-utils, ... }@inputs:
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
        pkgs = import nixpkgs { inherit (pkg-opts) system config;};
        pkgs-stable = import nixpkgs-stable { inherit (pkg-opts) system config; };
      in rec {

        deps = with pkgs; [
          flutter
          git
        ];

        android-data = {
          abiVersion = "x86_64";
          platformVersion = "34";
        };

        # android = pkgs.androidenv.composeAndroidPackages {
        #   toolsVersion = "26.1.1";
        #   platformToolsVersion = "34.0.5";
        #   buildToolsVersions = [ "30.0.0"  "30.0.3" "31.0.0" "34.0.0" ];
        #   includeEmulator = true;
        #   emulatorVersion = "34.1.9";
        #   platformVersions = [ "31" "33" "34" android-data.platformVersion ];
        #   includeSources = false;
        #   includeSystemImages = true;
        #   # systemImageTypes = [ "google_apis_playstore" ];
        #   abiVersions = [ "x86_64" "armeabi-v7a" "arm64-v8a" android-data.abiVersion ];
        #   cmakeVersions = [ "3.10.2" "3.18.1" ];
        #   includeNDK = true;
        #   ndkVersions = [ "23.1.7779620" "22.0.7026061" ];
        #   useGoogleAPIs = false;
        #   useGoogleTVAddOns = false;
        #   # avdmanager
        #   extraLicenses = [
        #       "android-sdk-preview-license"
        #       "android-googletv-license"
        #       "android-sdk-arm-dbt-license"
        #       "google-gdk-license"
        #       "intel-android-extra-license"
        #       "intel-android-sysimage-license"
        #       "mips-android-sysimage-license"
        #     ];
        #   # extras = ["extras;google;gcm"];
        # };

        android = pkgs-stable.androidenv.composeAndroidPackages {
          buildToolsVersions = [ "28.0.3" "30.0.3" ];
          platformVersions = [ "28" "33" "31" android-data.platformVersion ];
          abiVersions = [ "armeabi-v7a" "arm64-v8a" android-data.abiVersion ];
        };

        # android = pkgs.androidenv.androidPkgs_9_0;

        packages = rec {

          # fetchDeps = pkgs.stdenv.mkDerivation {
          #   name = "fetchDeps";
          #   buildInputs = with pkgs; deps ++ [ wget dart cacert ];
          #   src = frontend-dir;
          #   buildPhase = ''
          #     export HOME=$(mktemp -d)
          #     chmod -R 777 $HOME
          #     ls -la /etc/ssl/certs
          #     export DART_VM_OPTIONS="--root-certs-file=/etc/ssl/certs/ca-certificates.crt"
          #     # export PUB_HOSTED_URL=https://pub.flutter-io.cn
          #     # export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
          #     wget https://nixos.org/manual/nix/stable/language/import-from-derivation
          #     ls
          #     # mkdir -p /usr
          #     # mkdir -p /usr/share
          #     # mkdir -p /usr/local/share
          #     # mkdir -p /usr/local/share/ca-certificates
          #     # cp /etc/ssl/certs/ca-certificates.crt /usr/local/share/ca-certificates/ca-certificates.crt
          #     # update-ca-certificates
          #     flutter doctor
          #     date
          #     dart pub get --enforce-lockfile -vv
          #   '';
          #   installPhase = ''
          #     mkdir -p $out
          #     cp -r $HOME/.pub-cache $out/.pub-cache
          #   '';
          #   outputHashAlgo = "sha256";
          #   outputHashMode = "recursive";
          #   # outputHash = "sha256-4SePc3yGlBTGCoCeZtVL9A1NK5vv2CM8EnoRCinhPA0=";
          #   outputHash = pkgs.lib.fakeHash;
          # };

          avd = pkgs-stable.androidenv.emulateApp {
            name = "run-test-emulatorem";
            platformVersion = android-data.platformVersion;
            abiVersion = android-data.abiVersion; # armeabi-v7a, mips, x86_64
            systemImageType = "google_apis_playstore";
            # deviceName = "test-emulator";
          };


          apk = pkgs.stdenv.mkDerivation {
            name = "apk";
            buildInputs = with pkgs; deps ++ [ jdk17 android.androidsdk avd ];
            src = frontend-dir;
            ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
              # cp ${fetchDeps}/.pub-cache $HOME/.pub-cache
            configurePhase = ''
              #export HOME=$(mktemp -d)
              flutter pub get #--offline 
              #yes | flutter doctor --android-licenses
            '';
            buildPhase = ''
              # ls
              # flutter doctor
              flutter build apk
            '';
            installPhase = ''
              mkdir -p $out
              cp -r build/app/outputs/flutter-apk/app-release.apk $out/app-release.apk
            '';
            # TODO: install st that nix run .#apk opens avd
             shellHook = ''
                cd frontend
                zsh
                # code .
                ${avd}/bin/run-test-emulator
             '';
          };

          test = let
            buildToolsVersionForAapt2 = "34.0.0";
            androidComposition = (import inputs.nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                android_sdk.accept_license = true;
              };
          }).androidenv.composeAndroidPackages {
              # Installing both version for aapt2 and version that flutter wants
              buildToolsVersions = [buildToolsVersionForAapt2 "30.0.3"];
              platformVersions = ["34" "33" "31" "30"];
              abiVersions = ["armeabi-v7a" "arm64-v8a" "x86" "x86_64"];
              toolsVersion = "26.1.1";
              platformToolsVersion = "33.0.3";
              extraLicenses = [
                "android-googletv-license"
                "android-sdk-arm-dbt-license"
                "android-sdk-license"
                "android-sdk-preview-license"
                "google-gdk-license"
                "intel-android-extra-license"
                "intel-android-sysimage-license"
                "mips-android-sysimage-license"
              ];
            };
          in androidComposition.androidsdk;

          nixandroid = pkgs.flutter.buildFlutterApplication rec {
            name = "android apks";
            pname = "inspector";
            src = frontend-dir;
            autoPubspecLock = src + "/pubspec.lock";
            version = "0.0.1";
            targetFlutterPlatform = "android";
            gradleHash = "sha256:1l16lh94vzfg0vgxgajdqdj4b6smz3814jh0483pzvh7l5c2jp6d";
            
            gitHashes = {
              archive = "sha256-zTCwSe+Wls+ncCGauwPHE0pFVTvuBEZ56RHMVSBQSk0=";
              camera_android = "sha256-FMlNJGO3MJ2n+aoldkKrBiFvkkT0Yu4lZI0B+L34Hxs=";
              weather_icons = "sha256-g+QKuVgRb/cPR+8KCHs/35vlffjzhMdQkjKqD8ku1gY=";
            };
            # fixupPhase = ''
            #   echo "exec $out/bin/frontend" > $out/bin/$pname
            #   chmod +x $out/bin/$pname
            # '';
          };


          linux = pkgs.flutter.buildFlutterApplication rec {
            name = "linux-binary-executable";
            pname = "inspector";
            src = frontend-dir;
            autoPubspecLock = src + "/pubspec.lock";
            version = "0.0.1";
            # buildInputs = with pkgs; deps ++ [  ];
            # buildPhase = ''
            #   flutter build linux
            # '';
            # shellHook = ''
            #     cd frontend
            #     zsh
            #     # code .
            #  '';
            gitHashes = {
              archive = "sha256-zTCwSe+Wls+ncCGauwPHE0pFVTvuBEZ56RHMVSBQSk0=";
              camera_android = "sha256-FMlNJGO3MJ2n+aoldkKrBiFvkkT0Yu4lZI0B+L34Hxs=";
              weather_icons = "sha256-g+QKuVgRb/cPR+8KCHs/35vlffjzhMdQkjKqD8ku1gY=";
            };
            fixupPhase = ''
              echo "exec $out/bin/frontend" > $out/bin/$pname
              chmod +x $out/bin/$pname
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
