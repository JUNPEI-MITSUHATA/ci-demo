pipeline {
  agent any
  options { timestamps() }

  parameters {
    choice(name: 'TF_ACTION', choices: ['', 'apply', 'destroy'],
           description: 'Terraform action (empty=Plan only)')
  }

  stages {
      stage('Check AWS Auth') {
        steps {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
            sh 'aws sts get-caller-identity'
          }
        }
      }

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

  // ───────────── Terraform ステージ（ここから） ─────────────

    stage('Terraform Init & Plan') {
      environment {
        AWS_REGION = 'ap-northeast-1'
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
          dir('tf/aws') {
            sh '''
              set -eux

              # ビルド内で一貫したバケット名（衝突回避・秒を使わない）
              BUCKET_NAME="ci-demo-$(echo "${JOB_NAME}" | tr ' ' '-')-${BUILD_NUMBER}"
              echo "${BUCKET_NAME}" > .bucket_name

              terraform init -input=false
              terraform fmt -check
              terraform validate
              terraform plan -input=false -out=tfplan \
                -var="aws_region=${AWS_REGION}" \
                -var="bucket_name=${BUCKET_NAME}"
            '''
          }
        }
      }
      post {
        success {
          archiveArtifacts artifacts: 'tf/aws/tfplan,tf/aws/.bucket_name', fingerprint: true
        }
      }
    }

    stage('Terraform Apply (manual)') {
      when { expression { return params.TF_ACTION == 'apply' } }
      steps {
        input message: 'Apply Terraform changes to AWS?', ok: 'Proceed'
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
          dir('tf/aws') {
            sh '''
              set -eux
              # plan で固定した値を含む tfplan をそのまま適用（再計算しない）
              test -f tfplan
              terraform apply -input=false tfplan
              terraform output -json | tee tf-output.json || true
            '''
          }
        }
      }
      post {
        always {
          archiveArtifacts artifacts: 'tf/aws/tf-output.json', fingerprint: true
        }
      }
    }

    stage('Terraform Destroy (manual)') {
      when { expression { return params.TF_ACTION == 'destroy' } }
      environment {
        AWS_REGION = 'ap-northeast-1'
      }
      steps {
        input message: 'Destroy AWS resources?', ok: 'Destroy'
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
        dir('tf/aws') {
  sh '''
    set -eux

    # 既存の計画と名前をクリア
    rm -f tfplan .bucket_name || true

    # ── バケット名を安全に生成 ─────────────────────────────
    # ベース：ジョブ名＋ビルド番号を小文字化、英数とハイフン以外をハイフン化
    BASE="$(echo "${JOB_NAME}-${BUILD_NUMBER}" \
      | tr '[:upper:]' '[:lower:]' \
      | tr -cs 'a-z0-9-' '-' \
      | sed -E 's/^-+//; s/-+$//; s/--+/-/g')"

    # 一意性確保のためにUNIX時刻の短縮サフィックスを付与
    SUFFIX="$(date +%s)"

    CANDIDATE="ci-demo-${BASE}-${SUFFIX}"

    # 63文字に詰める（S3仕様）。先頭・末尾のハイフンも除去
    BUCKET_NAME="$(echo "$CANDIDATE" | cut -c1-63 | sed -E 's/^-+//; s/-+$//')"

    # 最低3文字を満たさない/空になった場合の保険
    if [ ${#BUCKET_NAME} -lt 3 ]; then
      BUCKET_NAME="ci-demo-${SUFFIX}"
    fi

    echo "${BUCKET_NAME}" | tee .bucket_name
    # ────────────────────────────────────────────────

    terraform init -input=false
    terraform fmt -check
    terraform validate
    terraform plan -input=false -out=tfplan \
      -var="aws_region=ap-northeast-1" \
      -var="bucket_name=${BUCKET_NAME}"
  '''
}
	}
      }
    }

    // ───────────── Terraform ステージ（ここまで） ─────────────


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

