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

            # Python (must be in buildInputs for headers)
            python
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
          ];

          # Set compiler environment variables
          CC = "clang";
          CXX = "clang++";

          # Force CMake to use Nix Python, not system Python
          Python_ROOT_DIR = "${python}";
          Python3_ROOT_DIR = "${python}";
          PYTHON_EXECUTABLE = "${python}/bin/python3";

          shellHook = ''
            echo "Mitsuba3 development environment"
            echo ""
            echo "Compiler: $(which clang++)"
            echo "Python:   ${python}/bin/python3"
            echo ""
            echo "Build commands:"
            echo "  cd mitsuba3"
            echo "  cmake -GNinja -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \\"
            echo "        -DMI_DEFAULT_VARIANTS='scalar_rgb,llvm_ad_rgb' \\"
            echo "        -DPython_ROOT_DIR=\$Python_ROOT_DIR \\"
            echo "        -DCMAKE_C_COMPILER=\$(which clang) \\"
            echo "        -DCMAKE_CXX_COMPILER=\$(which clang++)"
            echo "  cmake --build build"
            echo ""

            # Prevent CMake from finding system Python/compilers
            export Python_ROOT_DIR="${python}"
            export Python3_ROOT_DIR="${python}"
            export Python_FIND_STRATEGY="LOCATION"
            export Python3_FIND_STRATEGY="LOCATION"
          '';
        };
      }
    );
}
