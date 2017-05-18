def buildGhc() {
  steps {
    sh 'git submodule update --init --recursive'
    def speed = 'NORMAL'
    if (params.nightly) {
      speed = 'SLOW'
    }
    writeFile 'mk/build.mk'
              '''
              Validating=YES
              ValidateSpeed=${speed}
              ValidateHpc=NO
              BUILD_DPH=NO
              '''
    sh '''
        ./boot
        ./configure --enable-tarballs-autodownload
        make THREADS=${params.threads} test
        '''
  }
}

pipeline {
  agent any
  parameters {
    booleanParam(name: 'build_docs', defaultValue: false, description: 'build and upload documentation')
    string(name: 'threads', defaultValue: '2', description: 'available parallelism')
    booleanParam(name: 'nightly', defaultValue: false, description: 'are we building a nightly?')
  }

  stages {
    stage('Build') {
      steps {
        buildGhc()
      }
    }

    stage('Install testsuite dependencies') {
      when { environment expression { return params.nightly } }
      steps {
        sh 'cabal install --with-compiler=`pwd`/inplace/bin/ghc-stage2 --package-db=`pwd`/inplace/lib/package.conf.d mtl parallel parsec primitive QuickCheck random regex-compat syb stm utf8-string vector'
      }
    }

    stage('Normal testsuite run') {
      def target = 'test'
      if (params.nightly) {
        target = 'slowtest'
      }
      steps {
        sh 'make THREADS=${params.threads} ${target}'
      }
    }
  }
}
