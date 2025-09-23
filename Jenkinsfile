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
  }

   stage('Setup Tools (no sudo)') {
    steps {
    echo '公式Jenkinsイメージではsudo/aptは使いません（必要なら別手段へ）。'
    }
  }
}

stage('Lint (shellcheck)') {
  steps {
    sh '''
      set -e
      if [ -f scripts/healthcheck.sh ] && command -v shellcheck >/dev/null 2>&1; then
        shellcheck scripts/healthcheck.sh
      else
        echo "[skip] shellcheck or scripts/healthcheck.sh が見つかりません"
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
        # テストが無い場合 pytest は exit 5 を返すので許容
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

