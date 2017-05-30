#!groovy

properties(
  [
    parameters(
      [
        booleanParam(name: 'build_docs', defaultValue: false, description: 'build and upload documentation'),
        booleanParam(name: 'nightly', defaultValue: false, description: 'are we building a nightly?'),
        booleanParam(name: 'buildBindist', defaultValue: false, description: 'prepare and archive a binary distribution?'),
        booleanParam(name: 'runNofib', defaultValue: false, description: 'run nofib and archive results')
      ])
  ])

parallel (
  "linux x86-64"       : {
    node(label: 'linux && amd64') {buildGhc(runNoFib: params.runNofib)}
  },
  "linux x86-64 -> aarch64 unreg" : {
    node(label: 'linux && amd64') {buildGhc(crossTarget: 'aarch64-linux-gnu', unreg: true)}
  },
  "linux x86-64 -> aarch64" : {
    node(label: 'linux && amd64') {buildGhc(runNoFib: params.runNofib, crossTarget: 'aarch64-linux-gnu')}
  },
  "aarch64"            : {
    node(label: 'linux && aarch64') {buildGhc(runNoFib: false)}
  },
  "freebsd"            : {
    node(label: 'freebsd && amd64') {
      buildGhc(runNoFib: false, makeCmd: 'gmake', disableLargeAddrSpace: true)
    }
  },
  // Requires cygpath plugin?
  "windows 64"         : {
    node(label: 'windows && amd64') {
      withMingw('MINGW64') { buildGhc(runNoFib: false) }
    }
  },
  "windows 32"         : {
    node(label: 'windows && amd64') {
      withMingw('MINGW64') { buildGhc(runNoFib: false) }
    }
  },
  //"osx"                : {node(label: 'darwin') {buildGhc(runNoFib: params.runNoFib)}}
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

def buildGhc(params) {
  boolean runNoFib = params?.runNofib ?: false
  String crossTarget = params?.crossTarget
  boolean unreg = params?.unreg ?: false
  boolean disableLargeAddrSpace = params?.disableLargeAddrSpace ?: false
  String makeCmd = params?.makeCmd ?: 'make'

  stage('Checkout') {
    checkout scm
    sh "git submodule update --init --recursive"
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
    if (crossTarget) {
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

    def configure_opts = '--enable-tarballs-autodownload'
    if (crossTarget) {
      configure_opts += "--target=${crossTarget}"
    }
    if (disableLargeAddrSpace) {
      configure_opts += "--disable-large-address-space"
    }
    if (unreg) {
      configure_opts += "--enable-unregisterised"
    }
    sh """
       ./boot
       ./configure ${configure_opts}
       """
  }

  stage('Build') {
    sh "${makeCmd} -j${env.THREADS}"
  }
}

def testGhc(params) {
  String makeCmd = params?.makeCmd ?: 'make'

  stage('Install testsuite dependencies') {
    if (params.nightly && !crossTarget) {
      def pkgs = ['mtl', 'parallel', 'parsec', 'primitive', 'QuickCheck',
                  'random', 'regex-compat', 'syb', 'stm', 'utf8-string',
                  'vector']
      installPkgs pkgs
    }
  }

  stage('Run testsuite') {
    if (!crossTarget) {
      def target = 'test'
      if (params.nightly) {
        target = 'slowtest'
      }
      sh "${makeCmd} THREADS=${env.THREADS} ${target}"
    }
  }

  stage('Run nofib') {
    if (runNofib && !crossTarget) {
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

  stage('Prepare bindist') {
    if (params.buildBindist) {
      sh "${makeCmd} binary-dist"
      archiveArtifacts 'ghc-*.tar.xz'
    }
  }
}
