// Jenkinsfile (Declarative Pipeline) — Declarative 以外の場所に stage は置いていません
pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
    timeout(time: 60, unit: 'MINUTES')
  }

  environment {
    // 必要に応じて修正してください
    NODE_ENV = 'production'
    PYTHONUNBUFFERED = '1'
    AWS_DEFAULT_REGION = 'ap-northeast-1'
    TF_IN_AUTOMATION = 'true'
  }

  // tools ブロックは Jenkins にツール定義が無いと失敗しがちなので省略
  // (Node/Python は sh で存在チェックだけ行う)

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh '''
          echo "Commit: $(git rev-parse --short HEAD)"
          echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
        '''
      }
    }

    stage('Show Runtime Info') {
      steps {
        sh '''
          echo "===== Runtime ====="
          uname -a || true
          which bash && bash --version || true
          which python3 && python3 --version || true
          which pip3 && pip3 --version || true
          which node && node --version || true
          which npm && npm --version || true
          which terraform && terraform version || true
        '''
      }
    }

    stage('Install Dependencies') {
      steps {
        sh '''
          set -eux
          # Python
          if [ -f requirements.txt ] || [ -f requirements-dev.txt ]; then
            echo "[PY] Installing requirements..."
            python3 -m pip install --upgrade pip || true
            if [ -f requirements.txt ]; then python3 -m pip install -r requirements.txt; fi
            if [ -f requirements-dev.txt ]; then python3 -m pip install -r requirements-dev.txt; fi
          else
            echo "[PY] No requirements*.txt, skipping."
          fi

          # Node.js
          if [ -f package-lock.json ] || [ -f pnpm-lock.yaml ] || [ -f yarn.lock ]; then
            echo "[Node] Installing npm packages..."
            if [ -f package-lock.json ]; then npm ci; fi
            if [ -f pnpm-lock.yaml ]; then npx -y pnpm@latest i --frozen-lockfile; fi
            if [ -f yarn.lock ]; then npx -y yarn@stable install --frozen-lockfile; fi
          elif [ -f package.json ]; then
            echo "[Node] package.json found without lockfile, running npm install..."
            npm install
          else
            echo "[Node] No package.json, skipping."
          fi
        '''
      }
    }

    stage('Lint') {
      steps {
        sh '''
          set -eux
          RAN_ANY=0

          # Makefile の lint ターゲットがあれば使う
          if [ -f Makefile ] && grep -qE '^lint:' Makefile; then
            echo "[Make] make lint"
            make lint || exit 1
            RAN_ANY=1
          fi

          # Python lint (ruff/flake8/pylint のいずれかがあれば実行)
          if ls **/*.py >/dev/null 2>&1; then
            if python3 -m ruff --version >/dev/null 2>&1; then
              echo "[PY] ruff"
              python3 -m ruff check .
              RAN_ANY=1
            elif python3 -m flake8 --version >/dev/null 2>&1; then
              echo "[PY] flake8"
              python3 -m flake8 .
              RAN_ANY=1
            elif command -v pylint >/dev/null 2>&1; then
              echo "[PY] pylint"
              pylint $(git ls-files '*.py')
              RAN_ANY=1
            fi
          fi

          # JS/TS lint
          if [ -f package.json ]; then
            if npx -y eslint -v >/dev/null 2>&1; then
              echo "[JS] eslint"
              npx eslint . || exit 1
              RAN_ANY=1
            elif jq -r '.scripts.lint // empty' package.json >/dev/null 2>&1; then
              echo "[JS] npm run lint"
              npm run lint || exit 1
              RAN_ANY=1
            fi
          fi

          if [ "$RAN_ANY" -eq 0 ]; then
            echo "No lint configured. Skipping."
          fi
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          set -eux
          RAN_ANY=0

          # Make の test があれば
          if [ -f Makefile ] && grep -qE '^test:' Makefile; then
            echo "[Make] make test"
            make test
            RAN_ANY=1
          fi

          # Python: pytest があれば
          if command -v pytest >/dev/null 2>&1; then
            echo "[PY] pytest"
            pytest -q --maxfail=1 --disable-warnings --junitxml=reports/pytest-junit.xml || exit 1
            RAN_ANY=1
          fi

          # JS: npm test が定義されていれば
          if [ -f package.json ] && jq -r '.scripts.test // empty' package.json >/dev/null 2>&1; then
            echo "[JS] npm test"
            npm test || exit 1
            RAN_ANY=1
          fi

          if [ "$RAN_ANY" -eq 0 ]; then
            echo "No test configured. Skipping."
          fi
        '''
      }
    }

    stage('Build') {
      steps {
        sh '''
          set -eux
          mkdir -p build

          # Make の build があれば
          if [ -f Makefile ] && grep -qE '^build:' Makefile; then
            echo "[Make] make build"
            make build
            exit 0
          fi

          # JS: npm run build
          if [ -f package.json ] && jq -r '.scripts.build // empty' package.json >/dev/null 2>&1; then
            echo "[JS] npm run build"
            npm run build
            exit 0
          fi

          echo "No build step detected. Creating placeholder artifact."
          echo "built at $(date)" > build/placeholder.txt
        '''
      }
    }

    stage('Terraform (fmt/validate/plan)') {
      when {
        anyOf {
          expression { return fileExists('terraform') }
          expression { return fileExists('main.tf') }
        }
      }
      steps {
        withCredentials([
          // Jenkins に登録した AWS 認証情報の ID を設定してください（無ければこの withCredentials を削除）
          [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
        ]) {
          sh '''
            set -eux
            # Terraform 実行ディレクトリの選定
            TF_DIR="."
            if [ -d terraform ]; then TF_DIR="terraform"; fi
            cd "$TF_DIR"

            terraform --version

            terraform fmt -recursive
            terraform init -input=false -upgrade
            terraform validate

            # backend や var は環境に合わせて調整してください
            terraform plan -input=false -lock=false -out=tfplan

            mkdir -p ../tf-artifacts
            terraform show -no-color tfplan > ../tf-artifacts/plan.txt
          '''
        }
      }
    }

    stage('Archive Artifacts & Reports') {
      steps {
        script {
          // JUnit (存在しても無くても OK)
          junit allowEmptyResults: true, testResults: 'reports/**/*.xml'
          // アーティファクト
          archiveArtifacts artifacts: 'build/**, tf-artifacts/**', allowEmptyArchive: true, fingerprint: true
        }
      }
    }
  }

  post {
    always {
      echo "Build finished with result: ${currentBuild.currentResult}"
    }
    success {
      echo "✅ Success"
    }
    failure {
      echo "❌ Failure"
    }
  }
}

