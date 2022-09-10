# Proje Açıklaması
Git reposuna commit geldiği zaman CircleCI üzerinde aşağıdaki kurallar çalıştırılıp test ediliyor. Eğer bu testler geçmez ise ilgili kişi pull request'den gelen istekleri merge edemiyor.

* Dependency'lerin kurulmasi  
    ``` 
    yarn
    ``` 
* Lint kurallari kontrol
    ``` 
    yarn lint
    ```
* Formatlama kurallari kontrol
    ``` 
    yarn format:check
    ```


    İlgili dosya: `.circle/config.yml`

 CircleCI'dan başarı ile geçip, merge edildikten sonra Cloud Build tetikleniyor ve aşağıdaki işlemler gerçekleşiyor.

 * Projede bulunan Dockerfile build ediliyor.
 * Build edildikten sonra elde edilen image Artifact Registry'de bulunan Docker repository'sine gönderiliyor.
 * Repository'de bulunan latest tag'li image GKE'de bulunan Cluster üzerinde deploy ediliyor.

>develop branch'ine yapılan push işleminde `cloud-build/develop-build.yaml` tetikleniyor.  
master branch'ine yapılan push işleminde `cloud-build/master-build.yaml` tetikleniyor.

develop branch'ine push işlemi gerçekleştiği zaman `k8s-deployment/stage/stage-deployment.yaml` dosyası kubernetes üzerinde apply ediliyor. İlgili pod stage namespace'inde taint'i platform=stage olan node üzerinde ayağa kaldırılıyor.  

master branch'ine push işlemi gerçekleştiği zaman `k8s-deployment/prod/prod-deployment.yaml` dosyası kubernetes üzerinde apply ediliyor. İlgili pod production namespace'inde taint'i platform=production olan node üzerinde ayağa kaldırılıyor.

Build işlemi başarılı ya da başarısız olursa, ilgili kişiye Pub/Sub üzerinden tetiklenen Cloud Run'da çalışan bir uygulama ile mail gönderiliyor.

# Kubernetes Cluster Ortamının Hazırlanması
* stage ve production namespace'lerinin oluşturulması.
* service objelerinin oluşturulması. (`k8s-deployment/prod/prod-service.yaml` ve `k8s-deployment/stage/stage-service.yaml`)
* nginx ingress kurulumunun yapılması.
* Let's encrpyt ile issuer ve certificate oluşturulması. (`k8s-deployment/prod/prod-cert-issuer.yaml`,`prod-certificate.yaml` ve `k8s-deployment/stage/stage-cert-issuer.yaml`,`stage-certificate.yaml`)
* Ingress objelerinin oluşturulması. (`k8s-deployment/prod/prod-ingress.yaml` ve `k8s-deployment/stage/stage-ingress.yaml`)

# Nginx Ingress Kurulumu
* helm repo add nginx-stable https://helm.nginx.com/stable
* helm repo update
* helm install nginx-ingress nginx-stable/nginx-ingress


# Cert Manager ile SSL Kurulumu
* kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml
* kubectl apply -f k8s-deployment/prod/prod-cert-issuer.yaml
* kubectl apply -f k8s-deployment/stage/stage-cert-issuer.yaml
* kubectl apply -f k8s-deployment/prod/prod-certificate.yaml
* kubectl apply -f k8s-deployment/stage/stage-certificate.yaml

# Google Cloud Üzerinde SMTP Notification Kurulumu
* Bucket oluşturma.
    ``` 
    gsutil mb gs://<bucket_name>
    ```
* Notifier config dosyasını bucket'a gönderme.
    ``` 
    gsutil cp cloud-build/smtp.yaml gs://<bucket_name>/smtp.yaml
    ```
* Notifier uygulamasını Cloud Run üzerine deploy etme.
    ``` 
    gcloud run deploy <cr_name>--image=us-east1-docker.pkg.dev/gcb-release/cloud-build-notifiers/smtp:latest --update-env-vars=CONFIG_PATH=gs://<bucket_name>/smtp.yaml,PROJECT_ID=<Project_ID>
    ```
* Pub/Sub servisine gerekli izinleri verme.
    ``` 
    gcloud projects add-iam-policy-binding <Project_ID> --member=serviceAccount:service-<Project_ID>@gcp-sa-pubsub.iam.gserviceaccount.com --role=roles/iam.serviceAccountTokenCreator

    ```
* Pub/Sub servisinde subscription oluşturma.
    ``` 
    gcloud iam service-accounts create cloud-run-pubsub-invoker --display-name "Cloud Run Pub/Sub Invoker"
    ```
* Oluşturulan subscription'a Cloud Run Invoker izini verme.
    ``` 
    gcloud run services add-iam-policy-binding <cr_name>--member=serviceAccount:cloud-run-pubsub-invoker@<Project_ID>.iam.gserviceaccount.com --role=roles/run.invoker

    ```
* Cloud Build mesajlarını almak için Pub/Sub servisinde topic oluşturma.
    ``` 
    gcloud pubsub topics create cloud-builds

    ```
* Cloud Run'da çalışan uygulamaya mesaj atması için Pub/Sub üzerinden push subscriber oluşturma.
    ``` 
    gcloud pubsub subscriptions create email-subs --topic=cloud-builds --push-endpoint=<cr_url> --push-auth-service-account=cloud-run-pubsub-invoker@<Project_ID>.iam.gserviceaccount.com

    ```

    


