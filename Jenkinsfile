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
    node(label: 'freebsd && amd64') {buildGhc(runNoFib: false, makeCmd: 'gmake')}
  },
  // Requires cygpath plugin?
  // Make
  "windows 64"         : {
    node(label: 'windows && amd64') {buildGhc()}
  },
  "windows 32"         : {
    node(label: 'windows && amd64') {
      environment {
        PATH = 'C:\\msys64\\mingw32\\bin:C:\\msys64\\home\\ben\\ghc-8.0.2-i386:$PATH'
      }
      buildGhc()
    }
  },
  //"osx"                : {node(label: 'darwin') {buildGhc(runNoFib: params.runNoFib)}}
)

def installPackages(String[] pkgs) {
  sh "cabal install -j${env.THREADS} --with-compiler=`pwd`/inplace/bin/ghc-stage2 --package-db=`pwd`/inplace/lib/package.conf.d ${pkgs.join(' ')}"
}

def buildGhc(params) {
  boolean runNoFib = params?.runNofib ?: false
  String crossTarget = params?.crossTarget
  boolean unreg = params?.unreg ?: false
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
