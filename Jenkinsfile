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
  "linux x86-64" : {node(label: 'linux && amd64') {buildGhc(params.runNofib)}},
  "linux x86-64 -> aarch64" : {
                    node(label: 'linux && amd64') {buildGhc(params.runNofib, 'aarch64-linux-gnu')}},
  "aarch64"      : {node(label: 'linux && aarch64') {buildGhc(false)}},
  //"osx"          : {node(label: 'darwin') {buildGhc(false)}}
)

def installPackages(String[] pkgs) {
  sh "cabal install -j${env.THREADS} --with-compiler=`pwd`/inplace/bin/ghc-stage2 --package-db=`pwd`/inplace/lib/package.conf.d ${pkgs.join(' ')}"
}

def buildGhc(boolean runNofib, String cross_target=null) {
  stage('Clean') {
    checkout scm
    if (false) {
      sh 'make distclean'
    }
  }

  stage('Build') {
    sh 'git submodule update --init --recursive'
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
    if (cross_target) {
      build_mk += """
                  # Cross compiling
                  HADDOCK_DOCS=NO
                  BUILD_SPHINX_HTML=NO
                  BUILD_SPHINX_PDF=NO
                  """
    }
    writeFile(file: 'mk/build.mk', text: build_mk)

    def target_opt = ''
    if (cross_target) {
      target_opt = "--target=${cross_target}"
    }
    sh """
       ./boot
       ./configure --enable-tarballs-autodownload ${target_opt}
       make -j${env.THREADS}
       """
  }

  stage('Install testsuite dependencies') {
    if (params.nightly && !cross_target) {
      def pkgs = ['mtl', 'parallel', 'parsec', 'primitive', 'QuickCheck',
                  'random', 'regex-compat', 'syb', 'stm', 'utf8-string',
                  'vector']
      installPkgs pkgs
    }
  }

  stage('Run testsuite') {
    if (!cross_target) {
      def target = 'test'
      if (params.nightly) {
        target = 'slowtest'
      }
      sh "make THREADS=${env.THREADS} ${target}"
    }
  }

  stage('Run nofib') {
    if (runNofib && !cross_target) {
      installPkgs(['regex-compat'])
      sh """
         cd nofib
         make clean
         make boot
         make >../nofib.log 2>&1
         """
      archive 'nofib.log'
    }
  }

  stage('Prepare bindist') {
    if (params.buildBindist) {
      sh "make binary-dist"
      archive 'ghc-*.tar.xz'
    }
  }
}
