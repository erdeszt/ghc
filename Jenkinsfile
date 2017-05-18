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

//node { buildGhc(runNofib: params.runNofib) }
node(label: 'linux && amd64') {
  buildGhc(false)
}
node(label: 'aarch64') {
  buildGhc(false)
}

def installPackages(pkgs) {
  sh "cabal install -j${env.THREADS} --with-compiler=`pwd`/inplace/bin/ghc-stage2 --package-db=`pwd`/inplace/lib/package.conf.d ${pkgs.join(' ')}"
}

def buildGhc(runNofib) {
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
      installPkgs pkgs
    }
  }

  stage('Run testsuite') {
    def target = 'test'
    if (params.nightly) {
      target = 'slowtest'
    }
    sh "make THREADS=${env.THREADS} ${target}"
  }

  stage('Run nofib') {
    if (runNofib) {
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
