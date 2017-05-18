#!groovy

properties(
  [
    parameters(
      [
        booleanParam(name: 'build_docs', defaultValue: false, description: 'build and upload documentation'),
        booleanParam(name: 'nightly', defaultValue: false, description: 'are we building a nightly?')
      ])
  ])

def buildGhc() {
  stage('Build') {
    sh 'git submodule update --init --recursive'
    def speed = 'NORMAL'
    if (params.nightly) {
      speed = 'SLOW'
    }
    writeFile(
      file: 'mk/build.mk',
      text: """
            Validating=YES
            ValidateSpeed=${speed}
            ValidateHpc=NO
            BUILD_DPH=NO
            """)
    sh """
       ./boot
       ./configure --enable-tarballs-autodownload
       make -j${env.THREADS}
       """
  }

  stage('Install testsuite dependencies') {
    if (params.nightly) {
      def pkgs = ['mtl', 'parallel', 'parsec', 'primitive', 'QuickCheck',
                  'random', 'regex-compat', 'syb', 'stm', 'utf8-string',
                  'vector']
      sh "cabal install -j${env.THREADS} --with-compiler=`pwd`/inplace/bin/ghc-stage2 --package-db=`pwd`/inplace/lib/package.conf.d ${pkgs.join(' ')}"
    }
  }

  stage('Normal testsuite run') {
    def target = 'test'
    if (params.nightly) {
      target = 'slowtest'
    }
    sh "make THREADS=${env.THREADS} ${target}"
  }
}

node {
  buildGhc()
}
