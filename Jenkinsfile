pipeline {
  agent any
  options { timestamps() }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'git --version || true'
      }
    }

    stage('Setup Tools') {
      steps {
        // Jenkinsコンテナに必要ツールを入れる（初回のみ時間かかる）
        sh '''
          set -eux
          if ! command -v python3 >/dev/null; then
            sudo apt-get update
            sudo apt-get install -y python3 python3-venv python3-pip curl git shellcheck
          fi
        '''
      }
    }

    stage('Lint (shellcheck)') {
      steps {
        sh 'shellcheck scripts/healthcheck.sh'
      }
    }

    stage('Test (pytest)') {
      steps {
        sh '''
          set -eux
          python3 -m venv .venv
          . .venv/bin/activate
          pip install --upgrade pip
          pip install pytest
          pytest -q --maxfail=1 --disable-warnings
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '**/junit*.xml'  // 余地だけ確保（出力なしでもOK）
        }
      }
    }

    stage('Build Image (optional)') {
      when { expression { return fileExists('Dockerfile') } }
      steps {
        sh 'echo "skip: Docker build is optional in this demo"'
        // Dockerを使うなら、実行ノードにDockerが必要。今回は説明用にskip。
      }
    }

    stage('Package & Archive') {
      steps {
        sh '''
          echo "build artifact" > artifact.txt
          tar czf package.tgz app
        '''
        archiveArtifacts artifacts: 'artifact.txt,package.tgz', fingerprint: true
      }
    }

    stage('Publish to Artifactory (dry-run)') {
      when { expression { return env.ARTIFACTORY_URL && env.ARTIFACTORY_REPO && env.ARTIFACTORY_API_KEY } }
      steps {
        sh '''
          set -eux
          curl -H "X-JFrog-Art-Api: ${ARTIFACTORY_API_KEY}" \
               -T package.tgz \
               "${ARTIFACTORY_URL}/artifactory/${ARTIFACTORY_REPO}/ci-demo/package.tgz"
        '''
      }
    }
  }

  post {
    always { echo 'Pipeline finished.' }
  }
}
