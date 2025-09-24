pipeline {
  agent any
  options { timestamps() }

  stages {
      stage('Check AWS Auth') {
        steps {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
            sh 'aws sts get-caller-identity'
          }
        }
      }
    }

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
          gcc --version || true
          make --version || true
        '''
      }
    }

    stage('Lint (shellcheck)') {
      steps {
        sh '''
          set -eux
          # デモ用: スクリプトが無ければ作成
          if [ ! -f scripts/healthcheck.sh ]; then
            mkdir -p scripts
            cat > scripts/healthcheck.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "health OK"
EOF
            chmod +x scripts/healthcheck.sh
          fi
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

          # デモ用: テストが無ければ作成
          mkdir -p tests
          if [ ! -f tests/test_smoke.py ]; then
            cat > tests/test_smoke.py <<'EOF'
def test_smoke():
    assert 2 + 3 == 5
EOF
          fi

          # JUnit XML を必ず出力
          pytest -q --maxfail=1 --disable-warnings --junitxml=pytest-report.xml
        '''
      }
      post {
        always {
          junit allowEmptyResults: false, testResults: 'pytest-report.xml'
        }
      }
    }

    stage('Build with Makefile') {
      steps {
        sh '''
          set -eux
          # クリーン & ビルド
          make clean || true
          make
          # 実行して標準出力を明示的に見せる
          echo "=== Running hello binary ==="
          ./hello
          echo "=== Finished hello binary ==="
          # 実行結果をファイルにも残す（Artifactsで見られるように）
          ./hello > hello_output.txt
        '''
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
        archiveArtifacts artifacts: 'artifact.txt,package.tgz,hello_output.txt', fingerprint: true
      }
    }

    stage('Publish to Artifactory (dry-run)') {
      when {
        expression {
          return env.ARTIFACTORY_URL?.trim() && env.ARTIFACTORY_REPO?.trim() && env.ARTIFACTORY_API_KEY?.trim()
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
    always {
      echo 'Pipeline finished.'
    }
  }
}

