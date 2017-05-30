#!groovy

properties(
  [
    parameters(
      [
        booleanParam(name: 'build_docs', defaultValue: false, description: 'build and upload documentation'),
        booleanParam(name: 'nightly', defaultValue: false, description: 'are we building a nightly?'),
        booleanParam(name: 'runNofib', defaultValue: false, description: 'run nofib and archive results')
      ])
  ])

parallel (
  "linux x86-64"       : {
    node(label: 'linux && amd64') {buildAndTestGhc(targetTriple: 'x86_64-linux-gnu')}
  },
  "linux x86-64 -> aarch64 unreg" : {
    node(label: 'linux && amd64') {buildAndTestGhc(cross: true, targetTriple: 'aarch64-linux-gnu', unreg: true)}
  },
  "linux x86-64 -> aarch64" : {
    node(label: 'linux && amd64') {buildGhc(cross: true, targetTriple: 'aarch64-linux-gnu')}
    node(label: 'linux && aarch64') {testGhc(targetTriple: 'aarch64-linux-gnu')}
  },
  "aarch64"            : {
    node(label: 'linux && aarch64') {buildGhc(targetTriple: 'aarch64-linux-gnu')}
  },
  "freebsd"            : {
    node(label: 'freebsd && amd64') {
      buildGhc(targetTriple: 'x86_64-portbld-freebsd11.0', makeCmd: 'gmake', disableLargeAddrSpace: true)
    }
  },
  // Requires cygpath plugin?
  "windows 64"         : {
    node(label: 'windows && amd64') {
      withMingw('MINGW64') { buildAndTestGhc(targetTriple: 'x86_64-w64-mingw32') }
    }
  },
  "windows 32"         : {
    node(label: 'windows && amd64') {
      withMingw('MINGW32') { buildAndTestGhc(targetTriple: 'x86_64-pc-msys') }
    }
  },
  /*
  "osx"                : {
    node(label: 'darwin') {buildGhc(targetTriple: 'x86_64-apple-darwin16.0.0')}
  }
  */
)

def withMingw(String msystem, Closure f) {
  // Derived from msys2's /etc/msystem
  def msysRoot = 'C:\\msys64'
  if (msystem == 'MINGW32') {
    prefix = '${msysRoot}\\mingw32'
    carch = 'i686'
  } else if (msystem == 'MINGW64') {
    prefix = '${msysRoot}\\mingw64'
    carch = 'x86_64'
  } else {
    fail
  }
  chost = '${carch}-w64-mingw32'

  withEnv(["MSYSTEM=${msystem}",
           "PATH+mingw=C:\\msys64\\mingw32\\bin:C:\\msys64\\home\\ben\\ghc-8.0.2-i386\\bin",
           "MSYSTEM_PREFIX=${prefix}",
           "MSYSTEM_CARCH=${carch}",
           "MSYSTEM_CHOST=${chost}",
           "MINGW_CHOST=${chost}",
           "MINGW_PREFIX=${prefix}",
           "MINGW_PACKAGE_PREFIX=mingw-w64-${MSYSTEM_CARCH}",
           "CONFIG_SITE=${prefix}/etc/config.site"
          ], f)
}

def installPackages(String[] pkgs) {
  sh "cabal install -j${env.THREADS} --with-compiler=`pwd`/inplace/bin/ghc-stage2 --package-db=`pwd`/inplace/lib/package.conf.d ${pkgs.join(' ')}"
}

def buildAndTestGhc(params) {
  buildGhc(params)
  testGhc(params)
}

def buildGhc(params) {
  String targetTriple = params?.targetTriple
  boolean cross = params?.crossTarget ?: false
  boolean unreg = params?.unreg ?: false
  boolean disableLargeAddrSpace = params?.disableLargeAddrSpace ?: false
  String makeCmd = params?.makeCmd ?: 'make'

  stage('Checkout') {
    checkout scm
    sh "git submodule update --init --recursive"
    sh "${makeCmd} distclean"
  }

  stage('Configure') {
    def speed = 'NORMAL'
    if (params.nightly) {
      speed = 'SLOW'
    }
    build_mk = """
               Validating=YES
               ValidateSpeed=${speed}
               ValidateHpc=NO
               BUILD_DPH=NO
               """
    if (cross) {
      build_mk += """
                  # Cross compiling
                  HADDOCK_DOCS=NO
                  BUILD_SPHINX_HTML=NO
                  BUILD_SPHINX_PDF=NO
                  INTEGER_LIBRARY=integer-simple
                  WITH_TERMINFO=NO
                  """
    }
    writeFile(file: 'mk/build.mk', text: build_mk)

    def configure_opts = ['--enable-tarballs-autodownload']
    if (cross) {
      configure_opts += '--target=${targetTriple}'
    }
    if (disableLargeAddrSpace) {
      configure_opts += '--disable-large-address-space'
    }
    if (unreg) {
      configure_opts += '--enable-unregisterised'
    }
    sh """
       ./boot
       ./configure ${configure_opts.join(' ')}
       """
  }

  stage('Build') {
    sh "${makeCmd} -j${env.THREADS}"
  }

  stage('Prepare binary distribution') {
    sh "${makeCmd} binary-dist"
    def tarName = sh(script: "${makeCmd} -s echo VALUE=BIN_DIST_PREP_TAR_COMP",
                     returnStdout: true)
    def ghcVersion = sh(script: "${makeCmd} -s echo VALUE=ProjectVersion")
    writeFile "ghc-version" ghcVersion
    archiveArtifacts "../${tarName}"
    // Write a file so we can easily file the tarball and bindist directory later
    stash(name: "bindist-${targetTriple}", includes: "ghc-version,../${tarName}")
  }
}

def testGhc(params) {
  String targetTriple = params?.targetTriple
  String makeCmd = params?.makeCmd ?: 'make'
  boolean runNofib = params?.runNofib

  stage('Extract binary distribution') {
    sh "mkdir tmp"
    dir "tmp"
    unstash "bindist-${targetTriple}"
    def ghcVersion = readFile "ghc-version"
    sh "tar -xf ${ghcVersion}-${targetTriple}.tar.xz"
    dir ghcVersion
  }

  stage('Install testsuite dependencies') {
    if (params.nightly) {
      def pkgs = ['mtl', 'parallel', 'parsec', 'primitive', 'QuickCheck',
                  'random', 'regex-compat', 'syb', 'stm', 'utf8-string',
                  'vector']
      installPkgs pkgs
    }
  }

  stage('Run testsuite') {
    def target = 'test'
    if (params.nightly) {
      target = 'slowtest'
    }
    sh "${makeCmd} THREADS=${env.THREADS} ${target}"
  }

  stage('Run nofib') {
    if (runNofib) {
      installPkgs(['regex-compat'])
      sh """
         cd nofib
         ${makeCmd} clean
         ${makeCmd} boot
         ${makeCmd} >../nofib.log 2>&1
         """
      archiveArtifacts 'nofib.log'
    }
  }
}
