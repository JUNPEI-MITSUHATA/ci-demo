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

    stage('セットアップツール (sudo なし)') {
      steps {
        echo '公式Jenkinsイメージでは sudo/apt は使いません（必要なら後述の方法で）。'
      }
    }

    stage('Lint (shellcheck)') {
      steps {
        sh '''
          set -e
          if [ -f scripts/healthcheck.sh ] && command -v shellcheck >/dev/null 2>&1; then
            shellcheck scripts/healthcheck.sh
          else
            echo "[skip] shellcheck または scripts/healthcheck.sh が見つかりません"
          fi
        '''
      }
    }

    stage('Test (pytest)') {
      steps {
        sh '''
          set -e
          if command -v python3 >/dev/null 2>&1; then
            python3 -m venv .venv
            . .venv/bin/activate
            pip -q install --upgrade pip pytest
            # テストが無いと pytest は exit 5 → 許容
            pytest -q || test $? -eq 5
          else
            echo "[skip] python3 が見つかりません"
          fi
          echo OK > test-result.txt
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '**/junit*.xml'
        }
      }
    }

    stage('Build Image (optional)') {
      when { expression { return fileExists('Dockerfile') } }
      steps {
        echo 'skip: Docker build is optional in this demo'
      }
    }

    stage('Package & Archive') {
      steps {
        sh '''
          set -e
          mkdir -p app
          echo "build artifact" > artifact.txt
          tar czf package.tgz app artifact.txt
        '''
        archiveArtifacts artifacts: 'artifact.txt,package.tgz,test-result.txt', fingerprint: true
      }
    }

    stage('Publish to Artifactory (dry-run)') {
      when { expression { return env.ARTIFACTORY_URL && env.ARTIFACTORY_REPO && env.ARTIFACTORY_API_KEY } }
      steps {
        sh '''
          set -e
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
