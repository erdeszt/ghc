pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh 'git submodule update --init --recursive'
                sh '''
                   ./boot
                   ./configure --enable-tarballs-autodownload
                   make -j$THREADS
                   make THREADS=$THREADS test
                   '''
            }
        }
    }
}
