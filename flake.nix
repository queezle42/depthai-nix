{
  inputs = {

    # Downgrade nixpkgs for working spdlog/fmt package versions
    nixpkgs.url = github:NixOS/nixpkgs/8949f6984d90d3f6d16883d60ace71f04220ebb2;
    #nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

    xlink.url = github:luxonis/XLink/develop;
    xlink.flake = false;

    depthai-core.url = "https://github.com/luxonis/depthai-core";
    depthai-core.flake = false;
    depthai-core.type = "git";
    depthai-core.submodules = true;

    fp16.url = github:hunter-packages/FP16;
    fp16.flake = false;

    psimd.url = github:Maratyszcza/psimd;
    psimd.flake = false;

    libnop.url = github:luxonis/libnop/develop;
    libnop.flake = false;
  };

  outputs = { self, nixpkgs, xlink, depthai-core, fp16, psimd, libnop }:
  with nixpkgs.lib;
  let
    systems = platforms.unix;
    forAllSystems = genAttrs systems;

    # Version is coupled to depthai-core:
    # > cmake/Depthai/DepthaiBootloaderConfig.cmake
    depthai-bootloader = builtins.fetchurl {
      url = "https://artifacts.luxonis.com/artifactory/luxonis-myriad-release-local/depthai-bootloader/0.0.20/depthai-bootloader-fwp-0.0.20.tar.xz";
      name = "depthai-bootloader-fwp.tar.xz";
      sha256 = "sha256:1cl41fbq5rsak7n15gkv0kxj4z21v94hd01520wpy7636lbmyi6k";
    };

    # Version is coupled to depthai-core:
    # > cmake/Depthai/DepthaiDeviceSideConfig.cmake
    depthai-device = builtins.fetchurl {
      url = "https://artifacts.luxonis.com/artifactory/luxonis-myriad-snapshot-local/depthai-device-side/1a59c80266cd7a30ba874aa8d4a8277e0bf161ec/depthai-device-fwp-1a59c80266cd7a30ba874aa8d4a8277e0bf161ec.tar.xz";
      sha256 = "sha256:11mv79jlch67d70gm62w8gmi5fjpnjk0b3dnwkx1sy4k0niy3jlq";
    };

    depthai-core-drv = {
      clangStdenv,
      cmake,
      pkg-config,
      xlink,
      fp16,
      libnop,
      bzip2,
      libarchive,
      xz,
      zlib,
      spdlog,
      nlohmann_json,
      opencv,
    }: clangStdenv.mkDerivation {
      name = "depthai-core-unstable";
      src = depthai-core;
      nativeBuildInputs = [ cmake pkg-config ];
      buildInputs = [
        xlink
        bzip2
        fp16
        libnop
        libarchive
        xz
        zlib
        spdlog
        nlohmann_json
        opencv
      ];
      cmakeFlags = [
        "-DHUNTER_ENABLED=OFF"
        "-DBUILD_SHARED_LIBS=ON"
        "-DDEPTHAI_ENABLE_BACKWARD=OFF"
        "-DDEPTHAI_BINARIES_RESOURCE_COMPILE=ON"
        "-DDEPTHAI_BOOTLOADER_FWP=${depthai-bootloader}"
        "-DDEPTHAI_DEVICE_FWP=${depthai-device}"
      ];
      patches = [
        # Source: https://github.com/luxonis/depthai-core/issues/447
        ./no-hunter.patch
        ./no-download.patch
      ];
    };

    xlink-drv = {clangStdenv, cmake, libusb1}:
    clangStdenv.mkDerivation {
      name = "xlink-unstable";
      src = xlink;
      nativeBuildInputs = [ cmake ];
      buildInputs = [ libusb1 ];
      cmakeFlags = [
        "-DHUNTER_ENABLED=OFF"
        "-DXLINK_LIBUSB_SYSTEM=ON"
      ];
    };

    fp16-drv = { clangStdenv, cmake }:
    clangStdenv.mkDerivation {
      name = "fp16-unstable";
      src = fp16;
      nativeBuildInputs = [ cmake ];
      cmakeFlags = [
        "-DFP16_BUILD_TESTS=OFF"
        "-DFP16_BUILD_BENCHMARKS=OFF"
        "-DPSIMD_SOURCE_DIR=${psimd}"
      ];
    };

    libnop-drv = { clangStdenv, cmake, ninja, gtest }:
    clangStdenv.mkDerivation {
      name = "libnop-unstable";
      src = libnop;
      nativeBuildInputs = [ cmake ninja gtest ];
    };
  in {
    overlays.default = final: prev: {
      depthai-core = final.callPackage depthai-core-drv {};
      xlink = final.callPackage xlink-drv {};
      fp16 = final.callPackage fp16-drv {};
      libnop = final.callPackage libnop-drv {};
    };

    packages = forAllSystems (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; };
      in rec {
        default = depthai-core;
        depthai-core = pkgs.depthai-core;
        xlink = pkgs.xlink;
        fp16 = pkgs.fp16;
        libnop = pkgs.libnop;
      }
    );
  };
}
