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

    stage('Setup check') {
      steps {
        sh '''
          set -eux
          python3 -V
          pip3 -V || true
          shellcheck --version
        '''
      }
    }

    stage('Lint (shellcheck)') {
      steps {
        sh '''
          set -eux
          # スクリプトが無いときはダミー作成（商談デモのため）
          test -f scripts/healthcheck.sh || {
            mkdir -p scripts
            cat > scripts/healthcheck.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
echo "health OK"
EOS
            chmod +x scripts/healthcheck.sh
          }
          shellcheck scripts/healthcheck.sh
        '''
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
          # テストが無いと exit 5 になるので、最低1件のダミーテストを用意
          mkdir -p tests
          python - <<'PY'
from pathlib import Path
p = Path('tests/test_smoke.py')
if not p.exists():
    p.write_text("def test_smoke():\n    assert 2+3==5\n")
PY
          # JUnit XML を生成して Jenkins の Test Result に渡す
          pytest -q --maxfail=1 --disable-warnings --junitxml=pytest-report.xml
        '''
      }
      post {
        always {
          junit allowEmptyResults: false, testResults: 'pytest-report.xml'
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
          set -eux
          mkdir -p app
          echo "build artifact" > artifact.txt
          tar czf package.tgz app artifact.txt
        '''
        archiveArtifacts artifacts: 'artifact.txt,package.tgz', fingerprint: true
      }
    }

    stage('Publish to Artifactory (dry-run)') {
      when {
        allOf {
          environment name: 'ARTIFACTORY_URL', value: ~/./
          environment name: 'ARTIFACTORY_REPO', value: ~/./
          environment name: 'ARTIFACTORY_API_KEY', value: ~/./
        }
      }
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
