pipeline {
    agent any
    
    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['blue', 'green'], description: 'Choose which environment to deploy: Blue or Green')
        choice(name: 'DOCKER_TAG', choices: ['blue', 'green'], description: 'Choose the Docker image tag for the deployment')
        booleanParam(name: 'SWITCH_TRAFFIC', defaultValue: false, description: 'Switch traffic between Blue and Green')
    }
    
    tools{
        jdk 'jdk21'
        maven 'maven3'
    }
    
    environment{
        IMAGE_NAME = "prateekchhn9/bluegreendeployment"
        TAG = "${params.DOCKER_TAG}"  // The image tag now comes from the parameter
        SCANNER_HOME = tool 'sonar-scanner'
        KUBE_NAMESPACE = 'webapps'
    }

    stages {
        stage('Git checkout') {
            steps {
                git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/Prateekchhn9/Blue-Green-Deployment.git'
            }
        }
        stage('Compile') {
            steps {
                sh 'mvn compile'
            }
        }
        stage('Test') {
            steps {
                sh 'mvn test -DskipTests=true'
            }
        }
        stage('Trivy file scan') {
            steps {
                sh 'trivy fs --format table -o fs.html .'
            }
        }
        stage('SonarQube scan - code quality') {
            steps {
                withSonarQubeEnv('sonar-server') {
                sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=bluegreendeploy \
                -Dsonar.projectKey=bluegreendeploy \
                -Dsonar.java.binaries=target'''
                }
            }
        }
/*        
        stage('Quality gate check') {
            steps {
                timeout(time: 1, unit: 'HOURS'){
                waitForQualityGate abortPipeline: false
                }
            }
        }
*/
        stage('Build') {
            steps {
                sh 'mvn package -DskipTests=true'
            }
        }
        stage('Publish artifacts to nexus') {
            steps {
                withMaven(globalMavenSettingsConfig: 'maven-settings', jdk: 'jdk21', maven: 'maven3', traceability: true) {
                sh 'mvn deploy -DskipTests=true'
                }
            }
        }
        stage('Docker build and tag') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:${TAG} .'
            }
        }
        stage('Trivy image scan') {
            steps {
                sh 'trivy image --format table -o image.html ${IMAGE_NAME}:${TAG}'
            }
        }
        /*
        stage('Docker login') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-cred',usernameVariable: 'DOCKER_USER',passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo $DOCKER_PASS | /usr/bin/docker login \
                        -u $DOCKER_USER --password-stdin
                    '''
                }
            }
        }
        */
        stage('Docker push') {
            steps {
                    sh 'docker push ${IMAGE_NAME}:${TAG}'
            }
        }
        stage('EKS deployment') {
            steps {
                withKubeConfig(caCertificate: '', clusterName: 'prtk-cluster', contextName: '', credentialsId: 'k8-cred', namespace: 'webapps', restrictKubeConfigAccess: false, serverUrl: 'https://ED1EEACC0C82346E0053DA1D0DAC2B10.gr7.us-east-1.eks.amazonaws.com') {
                sh 'kubectl apply -f mysql-ds.yml -n ${KUBE_NAMESPACE}'
                }
            }
        }
        stage('Deploy SVC-APP') {
            steps {
                script {
                    withKubeConfig(caCertificate: '', clusterName: 'prtk-cluster', contextName: '', credentialsId: 'k8-cred', namespace: 'webapps', restrictKubeConfigAccess: false, serverUrl: 'https://ED1EEACC0C82346E0053DA1D0DAC2B10.gr7.us-east-1.eks.amazonaws.com') {
                        sh """ if ! kubectl get svc bankapp-service -n ${KUBE_NAMESPACE}; then
                                kubectl apply -f bankapp-service.yml -n ${KUBE_NAMESPACE}
                              fi
                        """
                   }
                }
            }
        }
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    def deploymentFile = ""
                    if (params.DEPLOY_ENV == 'blue') {
                        deploymentFile = 'app-deployment-blue.yml'
                    } else {
                        deploymentFile = 'app-deployment-green.yml'
                    }

                    withKubeConfig(caCertificate: '', clusterName: 'prtk-cluster', contextName: '', credentialsId: 'k8-cred', namespace: 'webapps', restrictKubeConfigAccess: false, serverUrl: 'https://ED1EEACC0C82346E0053DA1D0DAC2B10.gr7.us-east-1.eks.amazonaws.com') {
                        sh "kubectl apply -f ${deploymentFile} -n ${KUBE_NAMESPACE}"
                    }
                }
            }
        }
         stage('Switch Traffic Between Blue & Green Environment') {
            when {
                expression { return params.SWITCH_TRAFFIC }
            }
            steps {
                script {
                    def newEnv = params.DEPLOY_ENV

                    // Always switch traffic based on DEPLOY_ENV
                     withKubeConfig(caCertificate: '', clusterName: 'prtk-cluster', contextName: '', credentialsId: 'k8-cred', namespace: 'webapps', restrictKubeConfigAccess: false, serverUrl: 'https://ED1EEACC0C82346E0053DA1D0DAC2B10.gr7.us-east-1.eks.amazonaws.com') {
                        sh '''
                            kubectl patch service bankapp-service -p "{\\"spec\\": {\\"selector\\": {\\"app\\": \\"bankapp\\", \\"version\\": \\"''' + newEnv + '''\\"}}}" -n ${KUBE_NAMESPACE}
                        '''
                    }
                    echo "Traffic has been switched to the ${newEnv} environment."
                }
            }
        }
        stage('Verify Deployment') {
            steps {
                script {
                    def verifyEnv = params.DEPLOY_ENV
                   withKubeConfig(caCertificate: '', clusterName: 'prtk-cluster', contextName: '', credentialsId: 'k8-cred', namespace: 'webapps', restrictKubeConfigAccess: false, serverUrl: 'https://ED1EEACC0C82346E0053DA1D0DAC2B10.gr7.us-east-1.eks.amazonaws.com') {
                        sh """
                        kubectl get pods -l version=${verifyEnv} -n ${KUBE_NAMESPACE}
                        kubectl get svc bankapp-service -n ${KUBE_NAMESPACE}
                        """
                    }
                }
            }
        }
    }
    post {
    always {
        script {
            def jobName = env.JOB_NAME
            def buildNumber = env.BUILD_NUMBER
            def pipelineStatus = currentBuild.result ?: 'UNKNOWN'
            def bannerColor = pipelineStatus.toUpperCase() == 'SUCCESS' ? 'green' : 'red'

            def body = """
                <html>
                <body>
                <div style="border: 4px solid ${bannerColor}; padding: 10px;">
                <h2>${jobName} - Build ${buildNumber}</h2>
                <div style="background-color: ${bannerColor}; padding: 10px;">
                <h3 style="color: white;">Pipeline Status: ${pipelineStatus.toUpperCase()}</h3>
                </div>
                <p>Check the <a href="${BUILD_URL}">console output</a>.</p>
                </div>
                </body>
                </html>
            """

            emailext (
                subject: "${jobName} - Build ${buildNumber} - ${pipelineStatus.toUpperCase()}",
                body: body,
                to: 'Prateekchhn9@gmail.com',
                from: 'jenkins@example.com',
                replyTo: 'jenkins@example.com',
                mimeType: 'text/html',
                attachmentsPattern: 'trivy-image-report.html'
            )
        }
    }
}
}
