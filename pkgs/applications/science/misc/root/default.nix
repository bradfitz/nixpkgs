{ stdenv
, lib
, fetchurl
, fetchpatch
, makeWrapper
, cmake
, git
, ftgl
, gl2ps
, glew
, gsl
, libX11
, libXpm
, libXft
, libXext
, libGLU
, libGL
, libxml2
, llvm_9
, lz4
, xz
, pcre
, nlohmann_json
, pkg-config
, python
, xxHash
, zlib
, zstd
, libAfterImage
, giflib
, libjpeg
, libtiff
, libpng
, tbb
, Cocoa
, CoreSymbolication
, OpenGL
, noSplash ? false
}:

stdenv.mkDerivation rec {
  pname = "root";
  version = "6.24.06";

  src = fetchurl {
    url = "https://root.cern.ch/download/root_v${version}.source.tar.gz";
    sha256 = "sha256-kH9p9LrKHk8w7rSXlZjKdZm2qoA8oEboDiW2u6oO9SI=";
  };

  nativeBuildInputs = [ makeWrapper cmake pkg-config git ];
  buildInputs = [
    ftgl
    gl2ps
    glew
    pcre
    zlib
    zstd
    libxml2
    llvm_9
    lz4
    xz
    gsl
    xxHash
    libAfterImage
    giflib
    libjpeg
    libtiff
    libpng
    nlohmann_json
    python.pkgs.numpy
    tbb
  ]
  ++ lib.optionals (!stdenv.isDarwin) [ libX11 libXpm libXft libXext libGLU libGL ]
  ++ lib.optionals (stdenv.isDarwin) [ Cocoa CoreSymbolication OpenGL ]
  ;

  patches = [
    ./sw_vers.patch

    # Fix builtin_llvm=OFF support
    (fetchpatch {
      url = "https://github.com/root-project/root/commit/0cddef5d3562a89fe254e0036bb7d5ca8a5d34d2.diff";
      excludes = [ "interpreter/cling/tools/plugins/clad/CMakeLists.txt" ];
      sha256 = "sha256-VxWUbxRHB3O6tERFQdbGI7ypDAZD3sjSi+PYfu1OAbM=";
    })
  ];

  # Fix build against vanilla LLVM 9
  postPatch = ''
    sed \
      -e '/#include "llvm.*RTDyldObjectLinkingLayer.h"/i#define private protected' \
      -e '/#include "llvm.*RTDyldObjectLinkingLayer.h"/a#undef private' \
      -i interpreter/cling/lib/Interpreter/IncrementalJIT.h
  '';

  preConfigure = ''
    rm -rf builtins/*
    substituteInPlace cmake/modules/SearchInstalledSoftware.cmake \
      --replace 'set(lcgpackages ' '#set(lcgpackages '

    # Don't require textutil on macOS
    : > cmake/modules/RootCPack.cmake

    # Hardcode path to fix use with cmake
    sed -i cmake/scripts/ROOTConfig.cmake.in \
      -e 'iset(nlohmann_json_DIR "${nlohmann_json}/lib/cmake/nlohmann_json/")'

    patchShebangs build/unix/
  '' + lib.optionalString noSplash ''
    substituteInPlace rootx/src/rootx.cxx --replace "gNoLogo = false" "gNoLogo = true"
  '' + lib.optionalString stdenv.isDarwin ''
    # Eliminate impure reference to /System/Library/PrivateFrameworks
    substituteInPlace core/CMakeLists.txt \
      --replace "-F/System/Library/PrivateFrameworks" ""
  '';

  cmakeFlags = [
    "-Drpath=ON"
    "-DCMAKE_CXX_STANDARD=17"
    "-DCMAKE_INSTALL_BINDIR=bin"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
    "-Dbuiltin_llvm=OFF"
    "-Dbuiltin_nlohmannjson=OFF"
    "-Dbuiltin_openui5=OFF"
    "-Dalien=OFF"
    "-Dbonjour=OFF"
    "-Dcastor=OFF"
    "-Dchirp=OFF"
    "-Dclad=OFF"
    "-Ddavix=OFF"
    "-Ddcache=OFF"
    "-Dfail-on-missing=ON"
    "-Dfftw3=OFF"
    "-Dfitsio=OFF"
    "-Dfortran=OFF"
    "-Dimt=ON"
    "-Dgfal=OFF"
    "-Dgviz=OFF"
    "-Dhdfs=OFF"
    "-Dhttp=ON"
    "-Dkrb5=OFF"
    "-Dldap=OFF"
    "-Dmonalisa=OFF"
    "-Dmysql=OFF"
    "-Dodbc=OFF"
    "-Dopengl=ON"
    "-Doracle=OFF"
    "-Dpgsql=OFF"
    "-Dpythia6=OFF"
    "-Dpythia8=OFF"
    "-Drfio=OFF"
    "-Droot7=OFF"
    "-Dsqlite=OFF"
    "-Dssl=OFF"
    "-Dvdt=OFF"
    "-Dwebgui=OFF"
    "-Dxml=ON"
    "-Dxrootd=OFF"
  ]
  ++ lib.optional (stdenv.cc.libc != null) "-DC_INCLUDE_DIRS=${lib.getDev stdenv.cc.libc}/include"
  ++ lib.optionals stdenv.isDarwin [
    "-DOPENGL_INCLUDE_DIR=${OpenGL}/Library/Frameworks"
    "-DCMAKE_DISABLE_FIND_PACKAGE_Python2=TRUE"

    # fatal error: module map file '/nix/store/<hash>-Libsystem-osx-10.12.6/include/module.modulemap' not found
    # fatal error: could not build module '_Builtin_intrinsics'
    "-Druntime_cxxmodules=OFF"
  ];

  postInstall = ''
    for prog in rootbrowse rootcp rooteventselector rootls rootmkdir rootmv rootprint rootrm rootslimtree; do
      wrapProgram "$out/bin/$prog" \
        --prefix PYTHONPATH : "$out/lib"
    done
  '';

  setupHook = ./setup-hook.sh;

  meta = with lib; {
    homepage = "https://root.cern.ch/";
    description = "A data analysis framework";
    platforms = platforms.unix;
    maintainers = [ maintainers.veprbl ];
    license = licenses.lgpl21;
  };
}
