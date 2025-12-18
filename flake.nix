{
  description = "Mitsuba3 rendering framework development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };

        # Use clang with libstdc++ (not libc++) to avoid header conflicts
        llvmPackages = pkgs.llvmPackages_18;
        # Use clangStdenv which uses libstdc++ instead of libc++
        stdenv = pkgs.clangStdenv;

        # Python with required packages
        python = pkgs.python312.withPackages (ps: with ps; [
          numpy
          pytest
          pytest-xdist
        ]);

      in
      {
        devShells.default = pkgs.mkShell.override { inherit stdenv; } {
          buildInputs = with pkgs; [
            # Image I/O libraries
            libpng
            libjpeg

            # OpenGL and windowing (for nanogui)
            libGL
            libGLU
            xorg.libX11
            xorg.libXrandr
            xorg.libXinerama
            xorg.libXcursor
            xorg.libXi
            xorg.libXext
            glfw

            # Threading (for drjit/embree)
            tbb

            # Other dependencies
            zlib
          ];

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            git
            pkg-config

            # Clang toolchain
            llvmPackages.clang
            llvmPackages.llvm
            llvmPackages.lld
            llvmPackages.clang-tools  # includes clangd

            # Python
            python
          ];

          # Set compiler environment variables
          CC = "clang";
          CXX = "clang++";

          # Help CMake find Python
          PYTHON_EXECUTABLE = "${python}/bin/python3";

          shellHook = ''
            echo "Mitsuba3 development environment"
            echo ""
            echo "Compiler: clang (with libstdc++)"
            echo "Python:   python3.12"
            echo ""
            echo "NOTE: Use an AD variant (llvm_ad_rgb or cuda_ad_rgb) to avoid CMake conflicts."
            echo ""
            echo "Build commands:"
            echo "  cd mitsuba3 && mkdir -p build && cd build"
            echo "  cmake -GNinja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DMI_DEFAULT_VARIANTS='scalar_rgb,llvm_ad_rgb' .."
            echo "  ninja"
            echo ""
          '';
        };
      }
    );
}
