properties([pipelineTriggers([githubPush()])])
node {
  git url: 'https://github.com/divyavgirase/poller.git',
  credentialsId: 'git_cred',
  branch: 'a7'
}

pipeline {
  environment {

    REPO_NAME = "poller"
    registry = "divyavgirase/${REPO_NAME}"

    registryCredential = 'dockerhub_cred' //dockerhub_cred
    //GIT_HASH = sh(script: "git rev-parse HEAD", returnStdout: true).trim();
    GIT_HASH = '0f32161c299522e2286eb796fc7adbc4993c28e0'
    registry_url = "https://registry-1.docker.io/"

    db_name = "poller"
    db_host = "10.6.0.5"

    //kafka brokers
    broker1 = "10.0.2.5"
    broker2 = "10.0.1.6"
    broker3 = "10.0.2.7"
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
        sh " docker login -u divyavgirase -p $password";
        sh " GIT_HASH=`git rev-parse HEAD`";
        sh " git_hash=${GIT_HASH}"
        sh " gcloud config set project $projecr";
        sh " gcloud container clusters get-credentials $cluster --region us-east1";
        //sh" kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user $user";
        sh "gcloud auth activate-service-account --key-file=/home/ubuntu/terraform-user.json";
        sh ''' helm install ${REPO_NAME} ./helm/ --set image.repository=${registry} --set image.tag=0f32161c299522e2286eb796fc7adbc4993c28e0 --set env.user="admin" --set env.password="password" --set env.db=${db_name}  --set env.host=${db_host} --set env.poll="18000" --set env.broker1=${broker1} --set env.broker2=${broker2} --set env.broker3=${broker3}
                      '''
      }
    }
  }
}