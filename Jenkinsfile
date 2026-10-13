// =====================================================================
//  Terraform DevSecOps pipeline
//  Repo   : https://github.com/sathishbob/terraformdevsecops
//  Tools  : tfsec, Checkov, Terrascan, Terraform  (all run as Docker containers)
//  Jenkins: runs in Docker on Ubuntu, uses host Docker via /var/run/docker.sock
//  Creds  : Jenkins credential ID 'aws-creds' (Username = Access Key ID, Password = Secret Key)
// =====================================================================
 
// Runs a terraform command in the official image, as the Jenkins user
// so .terraform/ and tfplan stay owned by Jenkins (no permission issues on cleanup).
def tf(String args) {
  sh """
    docker run --rm -u \$(id -u):\$(id -g) \
      -e HOME=/tmp -e TF_IN_AUTOMATION=1 \
      -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION \
      -v "\$WORKSPACE:/work" -w /work \
      ${env.TF_IMAGE} ${args}
  """
}
 
pipeline {
  agent any
 
  options {
    timestamps()
    disableConcurrentBuilds()          // S3 state + DynamoDB lock: one run at a time
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }
 
  triggers {
    githubPush()                       // needs GitHub webhook -> http://<jenkins>:8080/github-webhook/
  }
 
  parameters {
    choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'],
           description: 'plan = scan + plan only | apply = scan + plan + approval + apply | destroy = plan -destroy + approval + destroy')
    booleanParam(name: 'ENFORCE_GATE', defaultValue: true,
                 description: 'Stop the pipeline if tfsec / Checkov / Terrascan find issues')
  }
 
  environment {
    AWS_DEFAULT_REGION = 'ap-southeast-1'          // matches provider.tf and S3 backend
    TF_IMAGE           = 'hashicorp/terraform:1.16.5'
    TFSEC_IMAGE        = 'aquasec/tfsec:latest'
    CHECKOV_IMAGE      = 'bridgecrew/checkov:latest'
    TERRASCAN_IMAGE    = 'tenable/terrascan:latest'
  }
 
  stages {
 
    stage('Git Checkout') {
      steps {
        // Uses the job's SCM config (Pipeline script from SCM):
        //   Repository URL : git@github.com:sathishbob/terraformdevsecops.git
        //   Credentials    : github  (SSH Username with private key)
        //   Branch         : */main
        checkout scm
 
        sh '''
          echo "Checked out: ${GIT_BRANCH:-main} @ $(git rev-parse --short HEAD)"
          git log -1 --pretty=format:"Commit by %an: %s%n"
          ls -la
          rm -rf reports tfplan && mkdir -p reports
        '''
      }
    }
 
    // ------------------------------------------------------------------
    //  Shift-left: scan the Terraform code BEFORE it touches AWS
    //  Code is mounted read-only; JUnit reports are written via stdout.
    // ------------------------------------------------------------------
    stage('IaC Security Scans') {
      parallel {
 
        stage('tfsec') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              sh '''
                docker run --rm -v "$WORKSPACE:/src:ro" $TFSEC_IMAGE /src \
                  --no-color --format junit > reports/tfsec.xml
              '''
            }
          }
        }
 
        stage('Checkov') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              sh '''
                docker run --rm -v "$WORKSPACE:/tf:ro" $CHECKOV_IMAGE \
                  -d /tf --framework terraform --quiet --skip-download \
                  -o junitxml > reports/checkov.xml
              '''
            }
          }
        }
 
        stage('Terrascan') {
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
              sh '''
                docker run --rm -v "$WORKSPACE:/iac:ro" $TERRASCAN_IMAGE \
                  scan -i terraform -d /iac --non-recursive -o junit-xml > reports/terrascan.xml
              '''
            }
          }
        }
      }
    }
 
    stage('Scan Summary') {
      steps {
        sh '''
          echo "================ IaC security findings ================"
          for f in reports/tfsec.xml reports/checkov.xml reports/terrascan.xml; do
            n=$(grep -c "<failure" "$f" 2>/dev/null || true)
            printf "%-28s %s finding(s)\\n" "$f" "${n:-0}"
          done
          echo "Full details: Build -> Test Results"
        '''
      }
    }
 
    stage('Security Gate') {
      when {
        allOf {
          expression { params.ENFORCE_GATE }
          expression { params.ACTION != 'destroy' }   // never block a cleanup
        }
      }
      steps {
        script {
          if (currentBuild.currentResult != 'SUCCESS') {
            error('Security gate FAILED: fix the findings in Test Results (or add a justified skip) before deploying.')
          }
          echo 'Security gate PASSED'
        }
      }
    }
 
    stage('Terraform Init & Validate') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          script {
            tf('init -input=false')            // S3 backend: sathis-terraform-state-0810
            tf('validate -no-color')
            // formatting is a warning, not a blocker
            def rc = sh(returnStatus: true, script: """
              docker run --rm -v "\$WORKSPACE:/work:ro" -w /work ${env.TF_IMAGE} fmt -check -recursive -diff
            """)
            if (rc != 0) { echo 'WARNING: code is not terraform-fmt formatted (run: terraform fmt)' }
          }
        }
      }
    }
 
    stage('Terraform Plan') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          script {
            def destroyFlag = (params.ACTION == 'destroy') ? '-destroy' : ''
            tf("plan -input=false -no-color ${destroyFlag} -out=tfplan")
            sh """
              docker run --rm -u \$(id -u):\$(id -g) -e HOME=/tmp \
                -v "\$WORKSPACE:/work" -w /work ${env.TF_IMAGE} \
                show -no-color tfplan > reports/tfplan.txt
            """
          }
        }
      }
    }
 
    stage('Approval') {
      when { expression { params.ACTION in ['apply', 'destroy'] } }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          input message: "Run terraform ${params.ACTION}? Review reports/tfplan.txt first.",
                ok: "Yes, ${params.ACTION}"
        }
      }
    }
 
    stage('Terraform Apply / Destroy') {
      when { expression { params.ACTION in ['apply', 'destroy'] } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          script {
            tf('apply -input=false -no-color tfplan')     // applies exactly what was approved
            if (params.ACTION == 'apply') {
              tf('output -no-color instance_public_ip')
            }
          }
        }
      }
    }
  }
 
  post {
    always {
      junit allowEmptyResults: true, testResults: 'reports/*.xml'
      archiveArtifacts artifacts: 'reports/*', allowEmptyArchive: true
      sh 'rm -f tfplan'                                  // plan file can contain sensitive values
    }
    success  { echo "Pipeline finished: ${params.ACTION} OK" }
    unstable { echo 'Pipeline UNSTABLE: security findings present (gate disabled)' }
    failure  { echo 'Pipeline FAILED: see the stage logs / Test Results' }
  }
}
 
