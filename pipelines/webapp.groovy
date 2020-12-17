properties([pipelineTriggers([githubPush()])])
node {
  git url: 'https://github.com/divyavgirase/webapp.git',
  credentialsId: 'git_cred',
  branch: 'term'
}

pipeline {
  environment {

    REPO_NAME = "webapp"
    registry = "divyavgirase/${REPO_NAME}"

    registryCredential = 'dockerhub_cred' //dockerhub_cred
    GIT_HASH = sh(script: "git rev-parse HEAD", returnStdout: true).trim();
    registry_url = "https://registry-1.docker.io/"

    db_name = $db_name
    db_host = $db_host

    //kafka brokers
    broker1 = $broker1
    broker2 = $broker2
    broker3 = $broker3
  }
  agent any
  stages {
    stage('Cloning Git') {
      steps {
        git branch: 'term',
        credentialsId: 'git_cred',
        url: "https://github.com/divyavgirase/${REPO_NAME}.git"
      }
    }
    stage('Building image') {
      steps {
        sh 'ls -al'
        script {
          GIT_HASH = sh(script: "git rev-parse HEAD", returnStdout: true).trim();
          sh(script: "docker build . -t ${REPO_NAME}")
        }
      }
    }
    stage('Deploy Image') {
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: 'dockerhub_cred', usernameVariable: 'USER', passwordVariable: 'PASSWORD')]) {
            withDockerRegistry([credentialsId: "dockerhub_cred", url: "${registry_url}"]) {
              sh(script: "docker login -u $USER -p $PASSWORD")
              sh(script: "docker tag ${REPO_NAME} ${registry}:${GIT_HASH}")
              sh(script: "docker push ${registry}:${GIT_HASH}")
            }

          }
        }
      }
    }
    stage('Deploy To K8S') {
      steps {
        sh " docker login -u $user -p $password";
        sh " GIT_HASH=`git rev-parse HEAD`";
        sh " git_hash=${GIT_HASH}"
        sh " gcloud config set project $project";
        sh " gcloud container clusters get-credentials $cluster --region us-east1";
        sh " kubectl create clusterrolebinding cluster-admin-binding   --clusterrole cluster-admin --user $user";
        sh "gcloud auth activate-service-account --key-file=/home/ubuntu/terraform-user.json";
        sh ''' helm install ${REPO_NAME} ./helm/ --set image.repository=${registry} --set image.tag=${GIT_HASH} --set env.dbusername="admin" --set env.dbpassword="somethingstrong" --set env.dbname=${db_name}  --set env.dbhost=${db_host} --set env.poll="18000" --set env.broker1=${broker1} --set env.broker2=${broker2} --set env.broker3=${broker3}
                      '''
      }
    }
  }
}