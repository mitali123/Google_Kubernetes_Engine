properties([pipelineTriggers([githubPush()])])
node {
  git url: 'https://github.com/divyavgirase/app-prereq-helm-charts.git',
  credentialsId: 'git_cred',
  branch: 'a7'
}

pipeline {
  environment {

    REPO_NAME = "app-prereq-helm-charts"
    registry = "divyavgirase/${REPO_NAME}"

    registryCredential = 'dockerhub_cred' //dockerhub_cred
    //GIT_HASH = sh(script: "git rev-parse HEAD", returnStdout: true).trim();
    GIT_HASH = '8a7eaa331548fe90a7e538d07f9ea1136f88fdf6'
    registry_url = "https://registry-1.docker.io/"
  }
  agent any
  stages {
    stage('Cloning Git') {
      steps {
        git branch: 'a7',
        credentialsId: 'git_cred',
        url: "https://github.com/divyavgirase/${REPO_NAME}.git"
      }
    }

    stage('Deploy To K8S') {
      steps {
        sh " GIT_HASH=`git rev-parse HEAD`";
        sh " git_hash=${GIT_HASH}"
        sh " gcloud config set project $project";
        sh " gcloud container clusters get-credentials $cluster --region us-east1";
        sh "gcloud auth activate-service-account --key-file=/home/ubuntu/terraform-user.json";
        //sh" kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user $user";
        sh ''' helm install test ./test/  --skip-crds
                      '''
        sleep 30
        sh "kubectl create -f cert-issuer.yaml";
      }
    }

  }
}