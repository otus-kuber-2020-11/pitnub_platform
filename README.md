# pitnub_platform
pitnub Platform repository

## Оглавление
### [ДЗ Kubernetes-intro](#kubernetes-intro)
### [ДЗ Kubernetes-controllers](#kubernetes-controllers)
### [ДЗ Kubernetes-security](#kubernetes-security)
### [ДЗ Kubernetes-networks](#kubernetes-networks)
### [ДЗ Kubernetes-volumes](#kubernetes-volumes)


# Kubernetes-intro
1. Установил bash-completion: brew install bash-completion
2. Установил kubectl: brew install kubectl
3. Установил minikube: brew install minikube
4. Запуск minikube: minikube start
5. Установка dashboard: minikube dashboard
6. Установил консольный вариант dashboard k9s: brew install k9s
7. Опыты по удалению контейнеров:  
   $ minikube ssh  
   $ docker rm -f $(docker ps -a -q)  
   Если удалить все контейнеры - кластер самовосстановится.  
   Это удобно видеть в консоли k9s

   Еще одна проверка на прочность - удаление всех подов в системном namespace:  
   $ kubectl delete pods --all -n kube-system  
   Также удобно наблюдать за процессом восстановления в k9s

   Основной мастер-набор pod-ов контролируется Kubelet Node, в то время как другие (core-dns) управляются контроллером Репликации ReplicaSet.  
   Проверить это можно анализируя значение параметра "Controlled By:" в выводе команды: kubectl describe pods -n kube-system

Для выполнения домашней работы необходимо создать Dockerfile, в котором будет описан образ:
- Запускающий web-сервер на порту 8000
- Отдающий содержимое директории /app внутри контейнера
- Работающий с UID 1001

Для работы с докером установил Docker Desktop.

Создаем и переходим в ветку kubernetes-intro:
<pre>
git checkout -b kubernetes-intro
mkdir -p kubernetes-intro/web
cd web; vim Dockerfile

FROM nginx:alpine
LABEL maintainer="pitnub"
ARG nginx_uid=1001
ARG nginx_gid=1001
WORKDIR /app
EXPOSE 8000
RUN apk add shadow && usermod -u $nginx_uid -o nginx && groupmod -g $nginx_gid -o nginx \
 && sed -i '/listen/s/80;/8000;/' /etc/nginx/conf.d/default.conf \
 && sed -i '1,/root/s/\/usr\/share\/nginx\/html;/\/app;/' /etc/nginx/conf.d/default.conf
CMD ["nginx", "-g", "daemon off;"]
</pre>

Создаем образ:  
$ docker build -t pitnub/web:0.1 .

Отправил образ в docker-hub используя меню в Docker Desktop.

Создание первого манифеста:
<pre>
vim web-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
  - name: web
    image: pitnub/web:0.1
</pre>

Запуск пода:
<pre>
kubectl apply -f web-pod.yaml
pod/web created
kubectl get pods
NAME   READY   STATUS    RESTARTS   AGE
web    1/1     Running   0          4m19s
</pre>

Получение манифеста запущенного пода:  
kubectl get pod web -o yaml
  
Другой способ посмотреть описание pod - использовать ключ describe.  
Команда позволяет отследить текущее состояние объекта, а также события, которые с ним происходили.
<pre>
kubectl describe pod web

Name:         web
Namespace:    default
Priority:     0
Node:         minikube/192.168.99.100
Start Time:   Mon, 25 Jan 2021 23:14:09 +0200
Labels:       app=web
Annotations:  
Status:       Running
IP:           172.17.0.5
IPs:
  IP:  172.17.0.5
Containers:
  web:
    Container ID:   docker://2c1cd8015cfc37387dc2654339a69cbe65a5b0e951699f130a806a77038cb5f6
    Image:          pitnub/web:0.1
    Image ID:       docker-pullable://pitnub/web@sha256:6164840e83db0cda6217a347a8401ef36848646c71e5ea9b92c61df20cf7cca4
    Port:           
    Host Port:      
    State:          Running
      Started:      Mon, 25 Jan 2021 23:14:16 +0200
    Ready:          True
    Restart Count:  0
    Environment:    
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-vlgm7 (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  default-token-vlgm7:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-vlgm7
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  
Tolerations:     node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                 node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  15m   default-scheduler  Successfully assigned default/web to minikube
  Normal  Pulling    15m   kubelet            Pulling image "pitnub/web:0.1"
  Normal  Pulled     15m   kubelet            Successfully pulled image "pitnub/web:0.1" in 6.122254288s
  Normal  Created    15m   kubelet            Created container web
  Normal  Started    15m   kubelet            Started container web
</pre>

Добавление init-контейнера в наш pod, генерирующий страницу index.html.
<pre>
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
  - name: web
    image: pitnub/web:0.1
    volumeMounts:
    - name: app
      mountPath: /app
  initContainers:
  - name: init-data
    image: busybox:1.32.1
    command: ['sh', '-c', 'wget -O- https://tinyurl.com/otus-k8s-intro | sh']
    volumeMounts:
    - name: app
      mountPath: /app
  volumes:
  - name: app
    emptyDir: {}

kubectl delete pod web
kubectl apply -f web-pod.yaml
kubectl get pods -w
NAME   READY   STATUS     RESTARTS   AGE
web    0/1     Init:0/1   0          5s
web    0/1     Init:0/1   0          5s
web    0/1     PodInitializing   0          6s
web    1/1     Running           0          7s
</pre>

Проверка работоспособности web сервера.  
Мы воспользуемся командой kubectl port-forward
Если все выполнено правильно, на локальном компьютере по ссылке http://localhost:8000/index.html должна открыться страница.

kubectl port-forward --address localhost pod/web 8000:8000

В последующих домашних заданиях мы будем использовать микросервисное приложение https://github.com/GoogleCloudPlatform/microservices-demo  
Давайте познакомимся с приложением поближе и попробуем запустить внутри нашего кластера его компоненты.

Начнем с микросервиса frontend.
<pre>
git clone git@github.com:GoogleCloudPlatform/microservices-demo.git
cd microservices-demo/src/frontend
docker build -t pitnub/boutique-frontend:v0.0.1 .
docker push pitnub/boutique-frontend:v0.0.1
</pre>

Альтернативный способ запуска pod в нашем Kubernetes кластере:  
kubectl run frontend --image pitnub/boutique-frontend:v0.0.1 --restart=Never

Генерация манифеста средствами kubectl:  
kubectl run frontend --image pitnub/boutique-frontend:v0.0.1 --restart=Never --dry-run=client -o yaml > frontend-pod.yaml

Запущенный pod frontend находится в состоянии Error.  
Смотрим журнал:
<pre>
$ kubectl logs frontend
{"message":"Tracing enabled.","severity":"info","timestamp":"2021-01-29T17:17:50.135604049Z"}
{"message":"Profiling enabled.","severity":"info","timestamp":"2021-01-29T17:17:50.135697858Z"}
panic: environment variable "PRODUCT_CATALOG_SERVICE_ADDR" not set

goroutine 1 [running]:
main.mustMapEnv(0xc000366000, 0xb1d189, 0x1c)
	/src/main.go:259 +0x10b
main.main()
	/src/main.go:117 +0x510
</pre>

Удаляем pod frontend:  
$ kubectl delete pods frontend

Добавляем определения требуемых переменных в файл frontend-pod-healhy.yaml  
Переменные найдены по ссылке https://github.com/GoogleCloudPlatform/microservices-demo/blob/master/kubernetes-manifests/frontend.yaml
<pre>
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: frontend
  name: frontend
spec:
  containers:
  - image: pitnub/boutique-frontend:v0.0.1
    name: frontend
    env:
    - name: PRODUCT_CATALOG_SERVICE_ADDR
      value: "productcatalogservice:3550"
    - name: CURRENCY_SERVICE_ADDR
      value: "currencyservice:7000"
    - name: CART_SERVICE_ADDR
      value: "cartservice:7070"
    - name: RECOMMENDATION_SERVICE_ADDR
      value: "recommendationservice:8080"
    - name: SHIPPING_SERVICE_ADDR
      value: "shippingservice:50051"
    - name: CHECKOUT_SERVICE_ADDR
      value: "checkoutservice:5050"
    - name: AD_SERVICE_ADDR
      value: "adservice:9555"
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}
</pre>

Запускаем pod:  
$ kubectl apply -f frontend-pod-healthy.yaml


# Kubernetes-controllers

Установка KIND.
<pre>
$ brew install kind
$ kind version
kind v0.9.0 go1.15.2 darwin/amd64
</pre>

Будем использовать следующую конфигурацию нашего локального кластера - kind-config.yaml:

<pre>
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
</pre>

Cоздание кластера kind:
<pre>
$ kind create cluster --config kind-config.yaml
$ kubectl cluster-info --context kind-kind
Kubernetes control plane is running at https://127.0.0.1:57462
KubeDNS is running at https://127.0.0.1:57462/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
</pre>

Развернуто три master ноды и три worker ноды:
<pre>
$ kubectl get nodes
NAME                  STATUS   ROLES    AGE     VERSION
kind-control-plane    Ready    master   5m47s   v1.19.1
kind-control-plane2   Ready    master   4m47s   v1.19.1
kind-control-plane3   Ready    master   3m35s   v1.19.1
kind-worker           Ready    none     3m13s   v1.19.1
kind-worker2          Ready    none     3m12s   v1.19.1
kind-worker3          Ready    none     3m12s   v1.19.1
</pre>

В предыдущем домашнем задании мы запускали standalone pod с микросервисом frontend.  
Пришло время доверить управление pod'ами данного микросервиса одному из контроллеров Kubernetes.  
Начнем с ReplicaSet и запустим одну реплику микросервиса frontend.  
Создайте и примените манифест frontend-replicaset.yaml  
Не забудьте изменить образ на собранный в предущем ДЗ.  

<pre>
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: server
        image: pitnub/boutique-frontend:v0.0.1

$ kubectl apply -f frontend-replicaset.yaml
error: error validating "frontend-replicaset.yaml": 
 error validating data: ValidationError(ReplicaSet.spec): missing required field "selector" 
 in io.k8s.api.apps.v1.ReplicaSetSpec; if you choose to ignore these errors, 
 turn validation off with --validate=false
</pre>

Как можно понять из появившейся ошибки - в описании ReplicaSet не хватает важной секции  
Определите, что необходимо добавить в манифест, исправьте его и примените вновь.  
Не забудьте про то, что без указания environment переменных сервис не заработает  
В результате вывод команды kubectl get pods -l app=frontend должен показывать,  
что запущена одна реплика микросервиса frontend:  

<pre>
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: server
        image: pitnub/boutique-frontend:v0.0.1
        env:
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
        - name: CURRENCY_SERVICE_ADDR
          value: "currencyservice:7000"
        - name: CART_SERVICE_ADDR
          value: "cartservice:7070"
        - name: RECOMMENDATION_SERVICE_ADDR
          value: "recommendationservice:8080"
        - name: SHIPPING_SERVICE_ADDR
          value: "shippingservice:50051"
        - name: CHECKOUT_SERVICE_ADDR
          value: "checkoutservice:5050"
        - name: AD_SERVICE_ADDR
          value: "adservice:9555"


$ kubectl apply -f frontend-replicaset.yaml
replicaset.apps/frontend created

$ kubectl get pods -l app=frontend
NAME             READY   STATUS    RESTARTS   AGE
frontend-j7jpr   1/1     Running   0          77s
</pre>

Одна работающая реплика - это уже неплохо, но в реальной жизни, как правило,  
требуется создание нескольких инстансов одного и того же сервиса для:  
 - Повышения отказоустойчивости  
 - Распределения нагрузки между репликами  
Давайте попробуем увеличить количество реплик сервиса adhoc командой:  
<pre>
$ kubectl scale replicaset frontend --replicas=3
replicaset.apps/frontend scaled
</pre>
<pre>
$ kubectl get pods -l app=frontend
NAME             READY   STATUS    RESTARTS   AGE
frontend-5kjn7   1/1     Running   0          21s
frontend-gh469   1/1     Running   0          21s
frontend-j7jpr   1/1     Running   0          3m16s
</pre>

Проверить, что ReplicaSet контроллер теперь управляет тремя репликами,  
и они готовы к работе, можно следующим образом:  
<pre>
$ kubectl get rs frontend
NAME       DESIRED   CURRENT   READY   AGE
frontend   3         3         3       4m31s
</pre>

Проверим, что благодаря контроллеру pod'ы действительно восстанавливаются после их ручного удаления:  
<pre>
$ kubectl delete pods -l app=frontend | kubectl get pods -l app=frontend -w
NAME             READY   STATUS    RESTARTS   AGE
frontend-5kjn7   1/1     Running   0          2m30s
frontend-gh469   1/1     Running   0          2m30s
frontend-j7jpr   1/1     Running   0          5m25s
frontend-5kjn7   1/1     Terminating   0          2m34s
frontend-9tfmx   0/1     Pending       0          0s
frontend-gh469   1/1     Terminating   0          2m35s
frontend-9tfmx   0/1     Pending       0          0s
frontend-j7jpr   1/1     Terminating   0          5m30s
frontend-sxx2d   0/1     Pending       0          0s
frontend-sxx2d   0/1     Pending       0          0s
frontend-9tfmx   0/1     ContainerCreating   0          0s
frontend-zsllz   0/1     Pending             0          1s
frontend-sxx2d   0/1     ContainerCreating   0          1s
frontend-zsllz   0/1     Pending             0          1s
frontend-gh469   0/1     Terminating         0          2m36s
frontend-5kjn7   0/1     Terminating         0          2m36s
frontend-zsllz   0/1     ContainerCreating   0          1s
frontend-j7jpr   0/1     Terminating         0          5m32s
frontend-5kjn7   0/1     Terminating         0          2m37s
frontend-5kjn7   0/1     Terminating         0          2m37s
frontend-9tfmx   1/1     Running             0          3s
frontend-sxx2d   1/1     Running             0          3s
frontend-j7jpr   0/1     Terminating         0          5m33s
frontend-j7jpr   0/1     Terminating         0          5m33s
frontend-zsllz   1/1     Running             0          4s
frontend-gh469   0/1     Terminating         0          2m47s
frontend-gh469   0/1     Terminating         0          2m47s
</pre>

Повторно примените манифест frontend-replicaset.yaml  
Убедитесь, что количество реплик вновь уменьшилось до одной.  
Измените манифест таким образом, чтобы из манифеста сразу разворачивалось три реплики сервиса, вновь примените его.  
<pre>
$ kubectl apply -f frontend-replicaset.yaml
replicaset.apps/frontend configured
$ kubectl get pods -l app=frontend
NAME             READY   STATUS    RESTARTS   AGE
frontend-sxx2d   1/1     Running   0          5m10s
$ kubectl get rs frontend
NAME       DESIRED   CURRENT   READY   AGE
frontend   1         1         1       11m

$ kubectl apply -f frontend-replicaset.yaml
replicaset.apps/frontend configured
$ kubectl get rs frontend
NAME       DESIRED   CURRENT   READY   AGE
frontend   3         3         3       12m
$ kubectl get pods -l app=frontend
NAME             READY   STATUS    RESTARTS   AGE
frontend-gzwvt   1/1     Running   0          10s
frontend-sxx2d   1/1     Running   0          6m58s
frontend-wscvm   1/1     Running   0          10s
</pre>

Давайте представим, что мы обновили исходный код и хотим выкатить новую версию микросервиса  
Добавьте на DockerHub версию образа с новым тегом (v0.0.2, можно просто перетегировать старый образ)  
<pre>
$ docker images
REPOSITORY                 TAG                  IMAGE ID       CREATED        SIZE
pitnub/boutique-frontend   v0.0.1               374e121a6262   3 weeks ago    41.1MB
$ docker tag 374e121a6262 pitnub/boutique-frontend:v0.0.2
$ docker images
REPOSITORY                 TAG                  IMAGE ID       CREATED        SIZE
pitnub/boutique-frontend   v0.0.1               374e121a6262   3 weeks ago    41.1MB
pitnub/boutique-frontend   v0.0.2               374e121a6262   3 weeks ago    41.1MB

$ docker push pitnub/boutique-frontend:v0.0.2
</pre>
Обновите в манифесте версию образа  
Примените новый манифест, параллельно запустите отслеживание происходящего:  
<pre>
$ kubectl apply -f frontend-replicaset.yaml | kubectl get pods -l app=frontend -w
NAME             READY   STATUS    RESTARTS   AGE
frontend-gzwvt   1/1     Running   0          45m
frontend-sxx2d   1/1     Running   0          51m
frontend-wscvm   1/1     Running   0          45m
</pre>
Кажется, ничего не произошло  

Давайте проверим образ, указанный в ReplicaSet:  
<pre>
$ kubectl get replicaset frontend -o=jsonpath='{.spec.template.spec.containers[0].image}'
pitnub/boutique-frontend:v0.0.2
</pre>
И образ из которого сейчас запущены pod, управляемые контроллером:  
<pre>
$ kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'
pitnub/boutique-frontend:v0.0.1 pitnub/boutique-frontend:v0.0.1 pitnub/boutique-frontend:v0.0.1
</pre>

Удалите все запущенные pod и после их пересоздания еще раз проверьте, из какого образа они развернулись:  
<pre>
$ kubectl delete pods -l app=frontend
$ kubectl get pods -l app=frontend -o=jsonpath='{.items[0:3].spec.containers[0].image}'
pitnub/boutique-frontend:v0.0.2 pitnub/boutique-frontend:v0.0.2 pitnub/boutique-frontend:v0.0.2
</pre>

Руководствуясь материалами лекции опишите произошедшую ситуацию, почему обновление ReplicaSet
не повлекло обновление запущенных pod ?  
Потому что задача этого контроллера обеспечить работу требуемого числа экземпляров приложения - а в нашем случае все экземпляры доступны.  

<pre>
git checkout -b kubernetes-controllers
mkdir kubernetes-controllers
cp frontend-replicaset.yaml kubernetes-controllers
</pre>

Мы, тем временем, перейдем к следующему контроллеру, более подходящему для развертывания и обновления приложений внутри Kubernetes.  
Для начала - воспроизведите действия, проделанные с микросервисом frontend для микросервиса paymentService.  
Результат:  
 - Собранный и помещенный в Docker Hub образ с двумя тегами v0.0.1 и v0.0.2
 - Валидный манифест paymentservice-replicaset.yaml с тремя репликами, разворачивающими из образа версии v0.0.1

<pre>
cd microservices-demo/src/paymentservice
$ docker build -t pitnub/boutique-paymentservice:v0.0.1 .
$ docker push pitnub/boutique-paymentservice:v0.0.1
</pre>

Получение манифеста пода в рабочем режиме:  
<pre>
$ kubectl run paymentservice --image pitnub/boutique-paymentservice:v0.0.1 --restart=Never
pod/paymentservice created
$ kubectl get pod paymentservice -o yaml > paymentservice-pod-active.yaml
$ kubectl delete pods paymentservice
pod "paymentservice" deleted
</pre>
Получение манифеста пода в холостом режиме:  
<pre>
$ kubectl run paymentservice --image pitnub/boutique-paymentservice:v0.0.1 --restart=Never --dry-run=client -o yaml > paymentservice-pod.yaml
</pre>
Запускаем pod:  
<pre>
$ kubectl apply -f paymentservice-pod.yaml
pod/paymentservice created
</pre>
Создаем манифест paymentservice-replicaset.yaml контроллера Replicaset c 3 репликами пода paymentservice:
<pre>
$ kubectl apply -f paymentservice-replicaset.yaml | kubectl get pods -l app=paymentservice -w
NAME                   READY   STATUS    RESTARTS   AGE
paymentservice-zh52n   0/1     Pending   0          0s
paymentservice-zh52n   0/1     Pending   0          0s
paymentservice-lhjqh   0/1     Pending   0          0s
paymentservice-8d66b   0/1     Pending   0          0s
paymentservice-lhjqh   0/1     Pending   0          1s
paymentservice-8d66b   0/1     Pending   0          1s
paymentservice-zh52n   0/1     ContainerCreating   0          1s
paymentservice-lhjqh   0/1     ContainerCreating   0          1s
paymentservice-8d66b   0/1     ContainerCreating   0          1s
paymentservice-zh52n   1/1     Running             0          3s
paymentservice-8d66b   1/1     Running             0          4s
paymentservice-lhjqh   1/1     Running             0          52s

$ docker images
REPOSITORY                       TAG                  IMAGE ID       CREATED        SIZE
pitnub/boutique-paymentservice   v0.0.1               5c9b35ce54b2   13 hours ago   323MB
$ docker tag 5c9b35ce54b2 pitnub/boutique-paymentservice:v0.0.2
$ docker images
REPOSITORY                       TAG                  IMAGE ID       CREATED        SIZE
pitnub/boutique-paymentservice   v0.0.1               5c9b35ce54b2   13 hours ago   323MB
pitnub/boutique-paymentservice   v0.0.2               5c9b35ce54b2   13 hours ago   323MB
$ docker push pitnub/boutique-paymentservice:v0.0.2

$ kubectl get rs,pod
NAME                             DESIRED   CURRENT   READY   AGE
replicaset.apps/paymentservice   3         3         3       10m

NAME                       READY   STATUS    RESTARTS   AGE
pod/paymentservice-8d66b   1/1     Running   0          10m
pod/paymentservice-lhjqh   1/1     Running   0          10m
pod/paymentservice-zh52n   1/1     Running   0          10m
</pre>

Удаляем контроллер (и соответственно поды):
<pre>
$ kubectl delete rs -l app=paymentservice
replicaset.apps "paymentservice" deleted
</pre>

Приступим к написанию Deployment манифеста для сервиса payment  
Скопируйте содержимое файла paymentservicereplicaset.yaml в файл paymentservice-deployment.yaml  
Измените поле kind с ReplicaSet на Deployment  
Манифест готов. Примените его и убедитесь, что в кластере Kubernetes  
действительно запустилось три реплики сервиса payment и каждая из них находится в состоянии Ready  
Обратите внимание, что помимо Deployment (kubectl get deployments) и трех pod,  
у нас появился новый ReplicaSet (kubectl get rs)  

<pre>
$ kubectl apply -f paymentservice-deployment.yaml | kubectl get pods -l app=paymentservice -w
NAME                              READY   STATUS    RESTARTS   AGE
paymentservice-77c59c696b-2d9qd   0/1     Pending   0          0s
paymentservice-77c59c696b-xj9zs   0/1     Pending   0          0s
paymentservice-77c59c696b-2d9qd   0/1     Pending   0          0s
paymentservice-77c59c696b-r6nt6   0/1     Pending   0          0s
paymentservice-77c59c696b-xj9zs   0/1     Pending   0          0s
paymentservice-77c59c696b-xj9zs   0/1     ContainerCreating   0          0s
paymentservice-77c59c696b-r6nt6   0/1     Pending             0          0s
paymentservice-77c59c696b-2d9qd   0/1     ContainerCreating   0          1s
paymentservice-77c59c696b-r6nt6   0/1     ContainerCreating   0          1s
paymentservice-77c59c696b-2d9qd   1/1     Running             0          3s
paymentservice-77c59c696b-r6nt6   1/1     Running             0          5s
paymentservice-77c59c696b-xj9zs   1/1     Running             0          8s

$ kubectl get rs,pod,deployment -l app=paymentservice
NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/paymentservice-77c59c696b   3         3         3       74s

NAME                                  READY   STATUS    RESTARTS   AGE
pod/paymentservice-77c59c696b-2d9qd   1/1     Running   0          74s
pod/paymentservice-77c59c696b-r6nt6   1/1     Running   0          74s
pod/paymentservice-77c59c696b-xj9zs   1/1     Running   0          74s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/paymentservice   3/3     3            3           74s
</pre>

Давайте попробуем обновить наш Deployment на версию образа v0.0.2  

<pre>
$ kubectl apply -f paymentservice-deployment.yaml | kubectl get pods -l app=paymentservice -w
NAME                              READY   STATUS    RESTARTS   AGE
paymentservice-77c59c696b-2d9qd   1/1     Running   0          11m
paymentservice-77c59c696b-r6nt6   1/1     Running   0          11m
paymentservice-77c59c696b-xj9zs   1/1     Running   0          11m
paymentservice-74b785f7c9-djmn8   0/1     Pending   0          0s
paymentservice-74b785f7c9-djmn8   0/1     Pending   0          0s
paymentservice-74b785f7c9-djmn8   0/1     ContainerCreating   0          0s
paymentservice-74b785f7c9-djmn8   1/1     Running             0          4s
paymentservice-77c59c696b-2d9qd   1/1     Terminating         0          11m
paymentservice-74b785f7c9-p7kdn   0/1     Pending             0          1s
paymentservice-74b785f7c9-p7kdn   0/1     Pending             0          1s
paymentservice-74b785f7c9-p7kdn   0/1     ContainerCreating   0          2s
paymentservice-74b785f7c9-p7kdn   1/1     Running             0          5s
paymentservice-77c59c696b-xj9zs   1/1     Terminating         0          11m
paymentservice-74b785f7c9-b7vrx   0/1     Pending             0          0s
paymentservice-74b785f7c9-b7vrx   0/1     Pending             0          0s
paymentservice-74b785f7c9-b7vrx   0/1     ContainerCreating   0          1s
paymentservice-74b785f7c9-b7vrx   1/1     Running             0          4s
paymentservice-77c59c696b-r6nt6   1/1     Terminating         0          11m
paymentservice-77c59c696b-2d9qd   0/1     Terminating         0          11m
paymentservice-77c59c696b-2d9qd   0/1     Terminating         0          11m
paymentservice-77c59c696b-2d9qd   0/1     Terminating         0          11m
paymentservice-77c59c696b-xj9zs   0/1     Terminating         0          11m
paymentservice-77c59c696b-xj9zs   0/1     Terminating         0          11m
paymentservice-77c59c696b-xj9zs   0/1     Terminating         0          11m
paymentservice-77c59c696b-r6nt6   0/1     Terminating         0          11m
paymentservice-77c59c696b-r6nt6   0/1     Terminating         0          12m
paymentservice-77c59c696b-r6nt6   0/1     Terminating         0          12m
</pre>

Обратите внимание на последовательность обновления pod.  
По умолчанию применяется стратегия Rolling Update:  
 - Создание одного нового pod с версией образа v0.0.2
 - Удаление одного из старых pod
 - Создание еще одного нового pod
   ...

Убедитесь что:  
 - Все новые pod развернуты из образа v0.0.2
   <pre>
   $ kubectl get pods -l app=paymentservice -o=jsonpath='{.items[0:3].spec.containers[0].image}'
   pitnub/boutique-paymentservice:v0.0.2 pitnub/boutique-paymentservice:v0.0.2 pitnub/boutique-paymentservice:v0.0.2
   </pre>
 - Создано два ReplicaSet:  
   - Один (новый) управляет тремя репликами pod с образом v0.0.2
   <pre>
   $ kubectl get rs -l app=paymentservice
   NAME                                        DESIRED   CURRENT   READY   AGE
   replicaset.apps/paymentservice-74b785f7c9   3         3         3       12m
   replicaset.apps/paymentservice-77c59c696b   0         0         0       23m
   $ kubectl get replicaset paymentservice-74b785f7c9 -o=jsonpath='{.spec.template.spec.containers[0].image}'
     pitnub/boutique-paymentservice:v0.0.2
   - Второй (старый) управляет нулем реплик pod с образом v0.0.1
   $ kubectl get replicaset paymentservice-77c59c696b -o=jsonpath='{.spec.template.spec.containers[0].image}'
     pitnub/boutique-paymentservice:v0.0.1
   </pre>

Также мы можем посмотреть на историю версий нашего Deployment:  
<pre>
$ kubectl rollout history deployment paymentservice
deployment.apps/paymentservice 
REVISION  CHANGE-CAUSE
1         none
2         none
</pre>

Представим, что обновление по каким-то причинам произошло неудачно и нам необходимо сделать откат.  
Kubernetes предоставляет такую возможность:  
<pre>
$ kubectl rollout undo deployment paymentservice --to-revision=1 | kubectl get rs -l app=paymentservice -w
</pre>
В выводе мы можем наблюдать, как происходит постепенное масштабирование вниз "нового" ReplicaSet, 
и масштабирование вверх "старого"  

<pre>
NAME                        DESIRED   CURRENT   READY   AGE
paymentservice-74b785f7c9   3         3         3       18m
paymentservice-77c59c696b   0         0         0       29m
paymentservice-77c59c696b   0         0         0       29m
paymentservice-77c59c696b   1         0         0       29m
paymentservice-77c59c696b   1         0         0       29m
paymentservice-77c59c696b   1         1         0       29m
paymentservice-77c59c696b   1         1         1       29m
paymentservice-74b785f7c9   2         3         3       18m
paymentservice-77c59c696b   2         1         1       29m
paymentservice-74b785f7c9   2         3         3       18m
paymentservice-74b785f7c9   2         2         2       18m
paymentservice-77c59c696b   2         1         1       29m
paymentservice-77c59c696b   2         2         1       29m
paymentservice-77c59c696b   2         2         2       29m
paymentservice-74b785f7c9   1         2         2       18m
paymentservice-74b785f7c9   1         2         2       18m
paymentservice-77c59c696b   3         2         2       29m
paymentservice-74b785f7c9   1         1         1       18m
paymentservice-77c59c696b   3         2         2       30m
paymentservice-77c59c696b   3         3         2       30m
paymentservice-77c59c696b   3         3         3       30m
paymentservice-74b785f7c9   0         1         1       18m
paymentservice-74b785f7c9   0         1         1       18m
paymentservice-74b785f7c9   0         0         0       18m
</pre>

С использованием параметров maxSurge и maxUnavailable 
самостоятельно реализуйте два следующих сценария развертывания:
 - Аналог blue-green:
   1. Развертывание трех новых pod
   2. Удаление трех старых pod
 - Reverse Rolling Update:
   1. Удаление одного старого pod
   2. Создание одного нового pod
   3. ...

Документация с описанием стратегий развертывания для Deployment
https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy
В результате должно получиться два манифеста:
 - paymentservice-deployment-bg.yaml
 - paymentservice-deployment-reverse.yaml

Аналог blue-green:
<pre>
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paymentservice
  labels:
    app: paymentservice
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 100%
      maxUnavailable: 0
  selector:
    matchLabels:
      app: paymentservice
  template:
    metadata:
      labels:
        app: paymentservice
    spec:
      containers:
      - name: paymentservice
        image: pitnub/boutique-paymentservice:v0.0.1

$ kubectl delete deploy -l app=paymentservice
deployment.apps "paymentservice" deleted

$ kubectl apply -f paymentservice-deployment-bg.yaml | kubectl get pods -l app=paymentservice -w
NAME                              READY   STATUS    RESTARTS   AGE
paymentservice-77c59c696b-xdj6s   0/1     Pending   0          0s
paymentservice-77c59c696b-ddx4f   0/1     Pending   0          0s
paymentservice-77c59c696b-244dl   0/1     Pending   0          0s
paymentservice-77c59c696b-xdj6s   0/1     Pending   0          0s
paymentservice-77c59c696b-ddx4f   0/1     Pending   0          0s
paymentservice-77c59c696b-244dl   0/1     Pending   0          0s
paymentservice-77c59c696b-xdj6s   0/1     ContainerCreating   0          1s
paymentservice-77c59c696b-ddx4f   0/1     ContainerCreating   0          1s
paymentservice-77c59c696b-244dl   0/1     ContainerCreating   0          1s
paymentservice-77c59c696b-ddx4f   1/1     Running             0          4s
paymentservice-77c59c696b-xdj6s   1/1     Running             0          6s
paymentservice-77c59c696b-244dl   1/1     Running             0          6s

$ kubectl rollout status deployment paymentservice
deployment "paymentservice" successfully rolled out

$ kubectl describe deployment paymentservice
Name:                   paymentservice
Namespace:              default
CreationTimestamp:      Sun, 21 Feb 2021 17:20:03 +0200
Labels:                 app=paymentservice
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=paymentservice
Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  0 max unavailable, 100% max surge
Pod Template:
  Labels:  app=paymentservice
  Containers:
   paymentservice:
    Image:        pitnub/boutique-paymentservice:v0.0.1
    Port:         none
    Host Port:    none
    Environment:  none
    Mounts:       none
  Volumes:        none
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  none
NewReplicaSet:   paymentservice-77c59c696b (3/3 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  117s  deployment-controller  Scaled up replica set paymentservice-77c59c696b to 3
</pre>

Обновляем наш Deployment на версию образа v0.0.2  
$ kubectl apply -f paymentservice-deployment-bg.yaml  
Одновременно наблюдаем за развертыванием подов в k9s.  
Когда новые три пода будут запущены запускаем команду постановки на паузу нашего deployment:  
$ kubectl rollout pause deployment paymentservice  
Примечание: лично у меня не получилось вовремя запаузить - старые поды все равно удалились...  
$ kubectl rollout resume deployment paymentservice  


Reverse Rolling Update: 

<pre>
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paymentservice
  labels:
    app: paymentservice
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1
  selector:
    matchLabels:
      app: paymentservice
  template:
    metadata:
      labels:
        app: paymentservice
    spec:
      containers:
      - name: paymentservice
        image: pitnub/boutique-paymentservice:v0.0.1

$ kubectl apply -f paymentservice-deployment-reverse.yaml
deployment.apps/paymentservice created

Меняем образ на v0.0.2
$ kubectl apply -f paymentservice-deployment-reverse.yaml | kubectl get pods -l app=paymentservice -w
NAME                              READY   STATUS    RESTARTS   AGE
paymentservice-77c59c696b-dz8hb   1/1     Running   0          3m47s
paymentservice-77c59c696b-np9v4   1/1     Running   0          3m46s
paymentservice-77c59c696b-vl627   1/1     Running   0          3m46s
paymentservice-77c59c696b-vl627   1/1     Terminating   0          3m47s
paymentservice-74b785f7c9-t2hgp   0/1     Pending       0          0s
paymentservice-74b785f7c9-t2hgp   0/1     Pending       0          0s
paymentservice-74b785f7c9-t2hgp   0/1     ContainerCreating   0          0s
paymentservice-74b785f7c9-t2hgp   1/1     Running             0          3s
paymentservice-77c59c696b-dz8hb   1/1     Terminating         0          3m51s
paymentservice-74b785f7c9-b69rx   0/1     Pending             0          0s
paymentservice-74b785f7c9-b69rx   0/1     Pending             0          0s
paymentservice-74b785f7c9-b69rx   0/1     ContainerCreating   0          0s
paymentservice-74b785f7c9-b69rx   1/1     Running             0          2s
paymentservice-77c59c696b-np9v4   1/1     Terminating         0          3m53s
paymentservice-74b785f7c9-fhggh   0/1     Pending             0          0s
paymentservice-74b785f7c9-fhggh   0/1     Pending             0          0s
paymentservice-74b785f7c9-fhggh   0/1     ContainerCreating   0          1s
paymentservice-74b785f7c9-fhggh   1/1     Running             0          3s
paymentservice-77c59c696b-vl627   0/1     Terminating         0          4m18s
paymentservice-77c59c696b-vl627   0/1     Terminating         0          4m20s
paymentservice-77c59c696b-vl627   0/1     Terminating         0          4m21s
paymentservice-77c59c696b-dz8hb   0/1     Terminating         0          4m22s
paymentservice-77c59c696b-np9v4   0/1     Terminating         0          4m25s
paymentservice-77c59c696b-np9v4   0/1     Terminating         0          4m30s
paymentservice-77c59c696b-np9v4   0/1     Terminating         0          4m30s
paymentservice-77c59c696b-dz8hb   0/1     Terminating         0          4m31s
paymentservice-77c59c696b-dz8hb   0/1     Terminating         0          4m32s
</pre>

Мы научились разворачивать и обновлять наши микросервисы, но можем ли быть уверены, что они корректно работают после выкатки?  
Один из механизмов Kubernetes, позволяющий нам проверить это probes  
https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/  

Давайте на примере микросервиса frontend посмотрим на то, как probes влияют на процесс развертывания.  
 - Создайте манифест frontend-deployment.yaml из которого можно развернуть три реплики pod с тегом образа v0.0.1
 - Добавьте туда описание readinessProbe.
   Описание можно взять из манифеста по ссылке 
   https://github.com/GoogleCloudPlatform/microservices-demo/blob/master/kubernetes-manifests/frontend.yaml
   
Примените манифест с readinessProbe.  
Если все сделано правильно, то мы вновь увидим три запущенных pod в описании которых (kubectl describe pod)  
будет указание на наличие readinessProbe и ее параметры  

<pre>
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: server
        image: pitnub/boutique-frontend:v0.0.1
        readinessProbe:
          initialDelaySeconds: 10
          httpGet:
            path: "/_healthz"
            port: 8080
            httpHeaders:
            - name: "Cookie"
              value: "shop_session-id=x-readiness-probe"
        env:
        - name: PRODUCT_CATALOG_SERVICE_ADDR
          value: "productcatalogservice:3550"
        - name: CURRENCY_SERVICE_ADDR
          value: "currencyservice:7000"
        - name: CART_SERVICE_ADDR
          value: "cartservice:7070"
        - name: RECOMMENDATION_SERVICE_ADDR
          value: "recommendationservice:8080"
        - name: SHIPPING_SERVICE_ADDR
          value: "shippingservice:50051"
        - name: CHECKOUT_SERVICE_ADDR
          value: "checkoutservice:5050"
        - name: AD_SERVICE_ADDR
          value: "adservice:9555"

$ kubectl apply -f frontend-deployment.yaml | kubectl get pods -l app=frontend -w
NAME                        READY   STATUS    RESTARTS   AGE
frontend-6f957c7c56-jdcnh   0/1     Pending   0          0s
frontend-6f957c7c56-jdcnh   0/1     Pending   0          0s
frontend-6f957c7c56-dzrgt   0/1     Pending   0          0s
frontend-6f957c7c56-st6m9   0/1     Pending   0          0s
frontend-6f957c7c56-dzrgt   0/1     Pending   0          0s
frontend-6f957c7c56-st6m9   0/1     Pending   0          0s
frontend-6f957c7c56-dzrgt   0/1     ContainerCreating   0          0s
frontend-6f957c7c56-jdcnh   0/1     ContainerCreating   0          1s
frontend-6f957c7c56-st6m9   0/1     ContainerCreating   0          1s
frontend-6f957c7c56-st6m9   0/1     Running             0          18s
frontend-6f957c7c56-dzrgt   0/1     Running             0          19s
frontend-6f957c7c56-jdcnh   0/1     Running             0          20s
frontend-6f957c7c56-st6m9   1/1     Running             0          30s
frontend-6f957c7c56-dzrgt   1/1     Running             0          30s
frontend-6f957c7c56-jdcnh   1/1     Running             0          32s

$ kubectl describe pod frontend-6f957c7c56-jdcnh | grep Readiness:
    Readiness:      http-get http://:8080/_healthz delay=10s timeout=1s period=10s #success=1 #failure=3
</pre>

Давайте попробуем сымитировать некорректную работу приложения и посмотрим, как будет вести себя обновление:
 - Замените в описании пробы URL /_healthz на /_health
 - Разверните версию v0.0.2

<pre>
$ kubectl apply -f frontend-deployment.yaml | kubectl get pods -l app=frontend -w
NAME                        READY   STATUS    RESTARTS   AGE
frontend-6f957c7c56-dzrgt   1/1     Running   0          5m34s
frontend-6f957c7c56-jdcnh   1/1     Running   0          5m34s
frontend-6f957c7c56-st6m9   1/1     Running   0          5m34s
frontend-7879956c64-nlbvv   0/1     Pending   0          0s
frontend-7879956c64-nlbvv   0/1     Pending   0          0s
frontend-7879956c64-nlbvv   0/1     ContainerCreating   0          0s
frontend-7879956c64-nlbvv   0/1     Running             0          1s

$ kubectl describe pod frontend-7879956c64-nlbvv | grep Readiness
    Readiness:      http-get http://:8080/_health delay=10s timeout=1s period=10s #success=1 #failure=3
  Warning  Unhealthy  9s (x13 over 2m9s)  kubelet  Readiness probe failed: HTTP probe failed with statuscode: 404
</pre>

Как можно было заметить, пока readinessProbe для нового pod не станет успешной - 
Deployment не будет пытаться продолжить обновление.  
На данном этапе может возникнуть вопрос - как автоматически отследить успешность выполнения Deployment 
(например для запуска в CI/CD).  
В этом нам может помочь следующая команда:  
$ kubectl rollout status deployment/frontend  
Waiting for deployment "frontend" rollout to finish: 1 out of 3 new replicas have been updated...  

Таким образом описание pipeline, включающее в себя шаг развертывания и шаг отката,  
в самом простом случае может выглядеть так (синтаксис GitLab CI):  

<pre>
deploy_job:
  stage: deploy
  script:
    - kubectl apply -f frontend-deployment.yaml
    - kubectl rollout status deployment/frontend --timeout=60s

rollback_deploy_job:
  stage: rollback
  script:
    - kubectl rollout undo deployment/frontend
  when: on_failure
</pre>

Рассмотрим еще один контроллер Kubernetes.  
Отличительная особенность DaemonSet в том, что при его применении на каждом физическом хосте 
создается по одному экземпляру pod, описанного в спецификации.  
Типичные кейсы использования DaemonSet:  
 - Сетевые плагины
 - Утилиты для сбора и отправки логов (Fluent Bit, Fluentd, etc...)
 - Различные утилиты для мониторинга (Node Exporter, etc...)
 - ...


Опробуем DaemonSet на примере Node Exporter  
 - Найдите в интернете или напишите самостоятельно манифест node-exporter-daemonset.yaml 
   для развертывания DaemonSet с Node Exporter
 - После применения данного DaemonSet и выполнения команды:
   kubectl port-forward <имя любого pod в DaemonSet> 9100:9100 
   метрики должны быть доступны на localhost: curl localhost:9100/metrics

<pre>
- Добавляем namespace monitoring
  $ kubectl create namespace monitoring
- Комментируем сервисную учетную запись в спецификации подов
  #serviceAccountName: node-exporter
- Применяем манифест
  $ kubectl apply -f node-exporter-daemonset.yaml -n monitoring
  daemonset.apps/node-exporter created
- Проверяем описание Daemonset
  $ kubectl describe daemonset.apps/node-exporter -n monitoring
- Проверяем поды
  $ kubectl get pods -n monitoring     
  NAME                  READY   STATUS    RESTARTS   AGE
  node-exporter-5cwv5   2/2     Running   0          38m
  node-exporter-955sm   2/2     Running   0          38m
  node-exporter-bgqd8   2/2     Running   0          38m
  node-exporter-bkt87   2/2     Running   0          38m
  node-exporter-sbkc2   2/2     Running   0          38m
  node-exporter-xxlsz   2/2     Running   0          38m
- $ kubectl port-forward pod/node-exporter-bgqd8 9100:9100 -n monitoring
  Forwarding from 127.0.0.1:9100 -> 9100
  Forwarding from [::1]:9100 -> 9100

- Как правило, мониторинг требуется не только для worker, но и для master нод. 
  При этом, по умолчанию, pod управляемые DaemonSet на master нодах не разворачиваются
- Найдите способ модернизировать свой DaemonSet таким образом, 
  чтобы Node Exporter был развернут как на master, так и на worker нодах (конфигурацию самих нод изменять нельзя)
- Отразите изменения в манифесте

Как видно выше у нас поды развернуты на всех 6 нодах.
Это произошлоа из-за "вседозволенной настройки в блоке tolerations":
tolerations:
- operator: Exists
У мастер-нод стоит ключ с эффектом NoSchedule:
$ kubectl describe node kind-control-plane | grep Taints
Taints:   node-role.kubernetes.io/master:NoSchedule
Если мы наоборот захотим не использовать мастер-ноды - то можно просто убрать блок tolerations.
$ kubectl delete daemonset.apps/node-exporter -n monitoring
daemonset.apps "node-exporter" deleted
$ kubectl apply -f node-exporter-daemonset.yaml -n monitoring
daemonset.apps/node-exporter created
$ kubectl get pods -n monitoring
NAME                  READY   STATUS    RESTARTS   AGE
node-exporter-8mb9f   2/2     Running   0          61s
node-exporter-wglkv   2/2     Running   0          61s
node-exporter-wgzr7   2/2     Running   0          61s
</pre>


# Kubernetes-security
### task01
 - Создать Service Account bob, дать ему роль admin в рамках всего кластера  
   <pre>
   $ kubectl apply -f 01-ServiceAccount.yaml
   serviceaccount/bob created
   $ kubectl apply -f 02-ClusterRoleBinding.yaml
   clusterrolebinding.rbac.authorization.k8s.io/bob-admin created
   $ kubectl get clusterrolebinding
   NAME            ROLE                     AGE
   bob-admin       ClusterRole/admin        99s
   </pre>
 - Создать Service Account dave без доступа к кластеру  
   <pre>
   $ kubectl apply -f 03-ServiceAccount.yaml
   serviceaccount/dave created
   </pre>
   Без привязки к роли доступа у данной учетки к кластеру не будет.

### task02
 - Создать Namespace prometheus  
   $ kubectl apply -f 01-ns-prometheus.yaml  
   namespace/prometheus created
 - Создать Service Account carol в этом Namespace  
   $ kubectl apply -f 02-ServiceAccount.yaml -n prometheus  
   serviceaccount/carol created
 - Дать всем Service Account в Namespace prometheus возможность делать get, list, watch
   в отношении Pods всего кластера  
   <pre>
   $ kubectl apply -f 03-ClusterRole.yaml                 
   clusterrole.rbac.authorization.k8s.io/prometheus-pods-read created
   $ kubectl apply -f 04-ClusterRoleBinding.yaml
   clusterrolebinding.rbac.authorization.k8s.io/prometheus created
   </pre>
   
### task03
 - Создать Namespace dev  
   $ kubectl apply -f 01-ns-dev.yaml  
   namespace/dev created
 - Создать Service Account jane в Namespace dev  
   $ kubectl apply -f 02-ServiceAccount.yaml  
   serviceaccount/jane created
 - Дать jane роль admin в рамках Namespace dev  
   $ kubectl apply -f 03-RoleBinding.yaml   
   rolebinding.rbac.authorization.k8s.io/jane-admin created
 - Создать Service Account ken в Namespace dev  
   $ kubectl apply -f 04-ServiceAccount.yaml  
   serviceaccount/ken created
 - Дать ken роль view в рамках Namespace dev  
   $ kubectl apply -f 05-RoleBinding.yaml   
   rolebinding.rbac.authorization.k8s.io/ken-view created


# Kubernetes-networks

У меня установлен Docker for Desktop, поэтому HyperKit доступен:
<pre>
$ hyperkit -v
hyperkit: v0.20200224-44-gb54460
Homepage: https://github.com/docker/hyperkit
License: BSD
</pre>

Удаляем предыдущий кластер в minikube(virtualbox) и запускаем новый с драйвером hyperkit:
<pre>
$ minikube delete
$ minikube start --driver=hyperkit
</pre>

Работа с тестовым веб-приложением
 - Добавление проверок Pod  
Откройте файл с описанием Pod из предыдущего ДЗ (kubernetes-intro/web-pod.yml)  
Добавьте в описание пода readinessProbe (можно добавлять его сразу после указания образа контейнера):

<pre>
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
  - name: web
    image: pitnub/web:0.1
    readinessProbe:       # Добавим проверку готовности
      httpGet:            # веб-сервера отдавать
        path: /index.html # контент
        port: 80
    volumeMounts:
    - name: app
      mountPath: /app
  initContainers:
  - name: init-data
    image: busybox:1.32.1
    command: ['sh', '-c', 'wget -O- https://tinyurl.com/otus-k8s-intro | sh']
    volumeMounts:
    - name: app
      mountPath: /app
  volumes:
  - name: app
    emptyDir: {}
    
$ kubectl apply -f web-pod.yaml
pod/web created
$ kubectl get pod/web
NAME   READY   STATUS    RESTARTS   AGE
web    0/1     Running   0          90s
$ kubectl describe pod/web

Containers:
  web:
    State:          Running
      Started:      Mon, 08 Mar 2021 14:13:00 +0200
    Ready:          False
    Restart Count:  0
    Readiness:      http-get http://:80/index.html delay=0s timeout=1s period=10s #success=1 #failure=3
...
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
...
Events:
  Type     Reason     Age                  From               Message
  ----     ------     ----                 ----               -------
  Normal   Scheduled  2m38s                default-scheduler  Successfully assigned default/web to minikube
  Normal   Pulling    2m37s                kubelet            Pulling image "busybox:1.32.1"
  Normal   Pulled     2m34s                kubelet            Successfully pulled image "busybox:1.32.1" in 3.213572449s
  Normal   Created    2m34s                kubelet            Created container init-data
  Normal   Started    2m34s                kubelet            Started container init-data
  Normal   Pulling    2m31s                kubelet            Pulling image "pitnub/web:0.1"
  Normal   Pulled     2m25s                kubelet            Successfully pulled image "pitnub/web:0.1" in 5.676032641s
  Normal   Created    2m25s                kubelet            Created container web
  Normal   Started    2m25s                kubelet            Started container web
  Warning  Unhealthy  7s (x14 over 2m17s)  kubelet            Readiness probe failed: Get "http://172.17.0.3:80/index.html": dial tcp 172.17.0.3:80: connect: connection refused
</pre>

Из листинга выше видно, что проверка готовности контейнера завершается неудачно. 
Это неудивительно - веб-сервер в контейнере слушает порт 8000 (по условиям первого ДЗ).  
Пока мы не будем исправлять эту ошибку, а добавим другой вид проверок: livenessProbe  

<pre>
livenessProbe:
  tcpSocket: { port: 8000 }
$ kubectl delete pod/web
pod "web" deleted
$ kubectl apply -f web-pod.yaml
pod/web created
</pre>

Вопрос для самопроверки:  
Q: Почему следующая конфигурация валидна, но не имеет смысла?

    livenessProbe:  
      exec:  
        command:  
          - 'sh'
          - '-c'
          - 'ps aux | grep my_web_server_process'
A: Потому что результат будет всегда успешным.  
Q: Бывают ли ситуации, когда она все-таки имеет смысл?  
A: Если перефразировать: Бывают ли ситуации, когда надо возвращать всегда успех?  
   Думаю нет, проще вообще не указывать этот пробник.  

  - Создание объекта Deployment
    - Скорее всего, в процессе изменения конфигурации Pod, 
      вы столкнулись с неудобством обновления конфигурации пода через kubectl (и уже нашли ключик --force).
    - В любом случае, для управления несколькими однотипными подами такой способ не очень подходит.  
      Создадим Deployment, который упростит обновление конфигурации пода и управление группами подов.  
<pre>
      $ git checkout -b kubernetes-networks
      $ mkdir kubernetes-networks
      $ cd kubernetes-networks
      В этой папке создайте новый файл web-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: pitnub/web:0.1
        livenessProbe:
          tcpSocket: { port: 8000 }
        readinessProbe:
          httpGet:
            path: /index.html
            port: 8000
        volumeMounts:
          - name: app
            mountPath: /app
      initContainers:
      - name: init-data
        image: busybox:1.32.1
        command: ['sh', '-c', 'wget -O- https://tinyurl.com/otus-k8s-intro | sh']
        volumeMounts:
          - name: app
            mountPath: /app
      volumes:
      - name: app
        emptyDir: {}
</pre>

    - Для начала удалим старый под из кластера:  
      $ kubectl delete pod/web --grace-period=0 --force  
    - И приступим к деплою:  
      $ kubectl apply -f web-deploy.yaml
      deployment.apps/web created
    - Посмотрим, что получилось:  
      $ kubectl describe deployment web
<pre>
Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
  Containers:
   web:
    Image:        pitnub/web:0.1
    Liveness:     tcp-socket :8000 delay=0s timeout=1s period=10s #success=1 #failure=3
    Readiness:    http-get http://:8000/index.html delay=0s timeout=1s period=10s #success=1 #failure=3
...
Conditions:
  Type           Status  Reason
  Progressing    True    NewReplicaSetAvailable
  Available      True    MinimumReplicasAvailable
OldReplicaSets:  
NewReplicaSet:   web-6f978c47bc (3/3 replicas created)
Events:
  Type    Reason             Age    From                   Message
  Normal  ScalingReplicaSet  7m59s  deployment-controller  Scaled up replica set web-6f978c47bc to 1
  Normal  ScalingReplicaSet  56s    deployment-controller  Scaled up replica set web-6f978c47bc to 3
</pre>

      - Добавьте в манифест ( web-deploy.yaml ) блок strategy (можно сразу перед шаблоном пода)  
<pre>
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0  
    maxSurge: 100%
</pre>
      - Наблюдаем за разными вариациями этих значений  
        За процессом можно понаблюдать с помощью kubectl get events --watch 
        или установить kubespy и использовать его (kubespy trace deploy)
      - Вариант с 0/0:  
        $ kubectl apply -f web-deploy.yaml  
        The Deployment "web" is invalid: spec.strategy.rollingUpdate.maxUnavailable: 
        Invalid value: intstr.IntOrString{Type:0, IntVal:0, StrVal:""}: may not be 0 when `maxSurge` is 0
      - Вариант с 100%/100%: приемлем
      - Вариант с 0/100%: аналог blue/green
  - Добавление сервисов в кластер (ClusterIP)  
    Создание Service  
    Для того, чтобы наше приложение было доступно внутри кластера (а тем более - снаружи), 
    нам потребуется объект типа Service.  
    Начнем с самого распространенного типа сервисов - ClusterIP.
    - ClusterIP выделяет для каждого сервиса IP-адрес из особого диапазона 
      (этот адрес виртуален и даже не настраивается на сетевых интерфейсах)
    - Когда под внутри кластера пытается подключиться к виртуальному IP-адресу сервиса, то нода, 
      где запущен под меняет адрес получателя в сетевых пакетах на настоящий адрес пода.
    - Нигде в сети, за пределами ноды, виртуальный ClusterIP не встречается.
    - ClusterIP удобны в тех случаях, когда:
      - Нам не надо подключаться к конкретному поду сервиса
      - Нас устраивается случайное расределение подключений между подами
      - Нам нужна стабильная точка подключения к сервису, независимая от подов, нод и DNS-имен
      Например:
       - Подключения клиентов к кластеру БД (multi-read) или хранилищу
       - Простейшая (не совсем, use IPVS, Luke) балансировка нагрузки внутри кластера
    - Создадим манифест для нашего сервиса в папке kubernetes-networks  
      Файл web-svc-cip.yaml:  

<pre>
apiVersion: v1
kind: Service
metadata:
  name: web-svc-cip
spec:
  selector:
    app: web
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000

$ kubectl apply -f web-svc-cip.yaml
service/web-svc-cip created
</pre>

    - Проверим результат (отметьте назначенный CLUSTER-IP):
      $ kubectl get services
      NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
      kubernetes    ClusterIP   10.96.0.1        <none>        443/TCP   10h
      web-svc-cip   ClusterIP   10.100.124.191   <none>        80/TCP    68s
    - Подключимся к ВМ Minikube (команда minikube ssh и затем sudo -i):
      - curl http://10.100.124.191/index.html - работает
      - ping 10.100.124.191 - ответа нет
      - arp -an; ip a - адреса 10.100.124.191 нет
      - iptables -nvL -t nat - нашли наш 10.100.124.191
        - Нужное правило находится в цепочке KUBE-SERVICES:
          Chain KUBE-SERVICES (2 references)
          pkts bytes target     prot opt in     out     source               destination         
          1    60 KUBE-MARK-MASQ  tcp  --  *      *      !10.244.0.0/16        10.100.124.191       /* default/web-svc-cip cluster IP */ tcp dpt:80
          1    60 KUBE-SVC-6CZTMAROCN3AQODZ  tcp  --  *      *       0.0.0.0/0            10.100.124.191       /* default/web-svc-cip cluster IP */ tcp dpt:80
        - Затем мы переходим в цепочку KUBE-SVC-6CZTMAROCN3AQODZ - 
          здесь находятся правила "балансировки" между цепочками KUBE-SEP-...
          - SVC - очевидно Service
          Chain KUBE-SVC-6CZTMAROCN3AQODZ (1 references)
          pkts bytes target     prot opt in     out     source               destination         
          0     0 KUBE-SEP-R7GFZ2Y4ZSCTFIRE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip */ statistic mode random probability 0.33333333349
          1    60 KUBE-SEP-Z6QHC4C2JAQDF7MX  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip */ statistic mode random probability 0.50000000000
          0     0 KUBE-SEP-C5Q7WHV7ALQOOLAZ  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip */
        - В цепочках KUBE-SEP-... находятся конкретные правила перенаправления трафика (через DNAT)
          - SEP - Service Endpoint
          Chain KUBE-SEP-R7GFZ2Y4ZSCTFIRE (1 references)
          pkts bytes target     prot opt in     out     source               destination         
          0     0 KUBE-MARK-MASQ  all  --  *      *       172.17.0.3           0.0.0.0/0            /* default/web-svc-cip */
          0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/web-svc-cip */ tcp to:172.17.0.3:8000
    
  - Включение режима балансировки IPVS
    Примечание: При запуске нового инстанса Minikube лучше использовать ключ --extra-config и сразу указать, что мы хотим IPVS
    - C версии 1.0.0 Minikube поддерживает работу kube-proxy в режиме IPVS. Попробуем включить его "наживую"
      - Включим IPVS для kube-proxy, исправив ConfigMap (конфигурация Pod, хранящаяся в кластере)
        - Выполните команду kubectl --namespace kube-system edit configmap/kube-proxy
          configmap/kube-proxy edited
        - Или minikube dashboard (далее надо выбрать namespace kube-system, Configs and Storage/Config Maps)
        - Теперь найдите в файле конфигурации kube-proxy строку mode: ""
        - Измените значение mode с пустого на ipvs и добавьте параметр strictARP: true и сохраните изменения  
<pre>
          ipvs:  
            strictARP: true  
          mode: "ipvs"
</pre>
        - Теперь удалим Pod с kube-proxy, чтобы применить новую конфигурацию 
          (он входит в DaemonSet и будет запущен автоматически)  
          kubectl --namespace kube-system delete pod --selector='k8s-app=kube-proxy'  
          pod "kube-proxy-8tvms" deleted
        - После успешного рестарта kube-proxy выполним команду minikube ssh и проверим, что получилось
        - Выполним команду iptables --list -nv -t nat в ВМ Minikube
        - Что-то поменялось, но старые цепочки на месте (хотя у них теперь 0 references)
          - kube-proxy настроил все по-новому, но не удалил мусор
          - Запуск kube-proxy --cleanup в нужном поде - тоже не помогает
            $ kubectl --namespace kube-system exec kube-proxy-ljkl2 -- kube-proxy --cleanup
          - Полностью очистим все правила iptables:
            - Создадим в ВМ с Minikube файл /tmp/iptables.cleanup:
<pre>
              *nat
              -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
              COMMIT
              *filter
              COMMIT
              *mangle
              COMMIT
</pre>
            - Применим конфигурацию: iptables-restore /tmp/iptables.cleanup  
            - Теперь надо подождать (примерно 30 секунд), пока kube-proxy восстановит правила для сервисов
            - Проверим результат iptables --list -nv -t nat
        - Итак, лишние правила удалены и мы видим только актуальную конфигурацию
          - kube-proxy периодически делает полную синхронизацию правил в своих цепочках
        - Как посмотреть конфигурацию IPVS? Ведь в ВМ нет утилиты ipvsadm ?
          - В ВМ выполним команду toolbox - в результате мы окажется в контейнере с Fedora  
<pre>
          # toolbox 
          Trying to pull docker://fedora:latest...
          Spawning container root-fedora-latest on /var/lib/toolbox/root-fedora-latest.
          Press ^] three times within 1s to kill container.
</pre>
          - Теперь установим ipvsadm:
            - dnf install -y ipvsadm && dnf clean all
          - Выполним ipvsadm --list -n и среди прочих сервисов найдем наш:
<pre>
          # ipvsadm --list -n
          IP Virtual Server version 1.2.1 (size=4096)
          Prot LocalAddress:Port Scheduler Flags
            -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
          TCP  10.96.0.1:443 rr
            -> 192.168.64.2:8443            Masq    1      0          0         
          TCP  10.96.0.10:53 rr
            -> 172.17.0.2:53                Masq    1      0          0         
          TCP  10.96.0.10:9153 rr
            -> 172.17.0.2:9153              Masq    1      0          0         
          TCP  10.100.124.191:80 rr
            -> 172.17.0.3:8000              Masq    1      0          0         
            -> 172.17.0.4:8000              Masq    1      0          0         
            -> 172.17.0.5:8000              Masq    1      0          0         
          UDP  10.96.0.10:53 rr
            -> 172.17.0.2:53                Masq    1      0          0 
</pre>
          - Теперь выйдем из контейнера toolbox и сделаем ping кластерного IP:
<pre>
          # ping 10.100.124.191
          PING 10.100.124.191 (10.100.124.191): 56 data bytes
          64 bytes from 10.100.124.191: seq=0 ttl=64 time=0.107 ms
          64 bytes from 10.100.124.191: seq=1 ttl=64 time=0.183 ms
          64 bytes from 10.100.124.191: seq=2 ttl=64 time=0.437 ms
          64 bytes from 10.100.124.191: seq=3 ttl=64 time=0.569 ms
</pre>
        - Итак, все работает. Но почему пингуется виртуальный IP?
          - Все просто - он уже не такой виртуальный. Этот IP теперь есть на интерфейсе kube-ipvs0:
<pre>
            # ip addr show kube-ipvs0
            14: kube-ipvs0: 'BROADCAST,NOARP' mtu 1500 qdisc noop state DOWN group default 
            link/ether 36:79:75:22:a4:ec brd ff:ff:ff:ff:ff:ff
            inet 10.96.0.10/32 scope global kube-ipvs0
               valid_lft forever preferred_lft forever
            inet 10.100.124.191/32 scope global kube-ipvs0
               valid_lft forever preferred_lft forever
            inet 10.96.0.1/32 scope global kube-ipvs0
               valid_lft forever preferred_lft forever
</pre>
        - Также, правила в iptables построены по-другому.
          Вместо цепочки правил для каждого сервиса, теперь используются хэш-таблицы (ipset).
          Можете посмотреть их, установив утилиту ipset в toolbox.
<pre>
          - # toolbox 
            Spawning container root-fedora-latest on /var/lib/toolbox/root-fedora-latest.
            Press ^] three times within 1s to kill container.
            [root@minikube ~]# dnf install ipset
            [root@minikube ~]# ipset list
            ...
            Name: KUBE-CLUSTER-IP
            Type: hash:ip,port
            Revision: 5
            Header: family inet hashsize 1024 maxelem 65536
            Size in memory: 408
            References: 2
            Number of entries: 5
            Members:
            10.96.0.10,udp:53
            10.100.124.191,tcp:80
            10.96.0.10,tcp:9153
            10.96.0.10,tcp:53
            10.96.0.1,tcp:443
</pre>
            
Доступ к приложению извне кластера
  - Установка MetalLB в Layer2-режиме
    MetalLB позволяет запустить внутри кластера L4-балансировщик,
    который будет принимать извне запросы к сервисам и раскидывать их между подами.
    Установка его проста (В продуктиве так делать не надо. Сначала стоит скачать файл и разобраться, что там внутри):
      - kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
      - kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
      - kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"  
    Проверьте, что были созданы нужные объекты:

<pre>
      - kubectl --namespace metallb-system get all
        NAME                            READY   STATUS    RESTARTS   AGE
        pod/controller-fb659dc8-mvffz   1/1     Running   0          7m6s
        pod/speaker-7t2pp               1/1     Running   0          7m6s

        NAME                     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                 AGE
        daemonset.apps/speaker   1         1         1       1            1           beta.kubernetes.io/os=linux   7m6s

        NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
        deployment.apps/controller   1/1     1            1           7m6s

        NAME                                  DESIRED   CURRENT   READY   AGE
        replicaset.apps/controller-fb659dc8   1         1         1       7m6s
</pre>
    Теперь настроим балансировщик с помощью ConfigMap
      - Создайте манифест metallb-config.yaml в папке kubernetes-networks:

<pre>
         apiVersion: v1
         kind: ConfigMap
         metadata:
           namespace: metallb-system
           name: config
         data:
           config: |
             address-pools:
               - name: default
                 protocol: layer2
                 addresses:
                   - "172.17.255.1-172.17.255.255"
</pre>

      - В конфигурации мы настраиваем:
        - Режим L2 (анонс адресов балансировщиков с помощью ARP)
        - Создаем пул адресов 172.17.255.1 - 172.17.255.255 - они будут назначаться сервисам с типом LoadBalancer
      - Теперь можно применить наш манифест: kubectl apply -f metallb-config.yaml
        configmap/config created
      - Контроллер подхватит изменения автоматически

  - Добавление сервиса LoadBalancer
      - Сделайте копию файла web-svc-cip.yaml в web-svc-lb.yaml и откройте его в редакторе.

<pre>
         apiVersion: v1
         kind: Service
         metadata:
           name: web-svc-lb
         spec:
           selector:
             app: web
           type: LoadBalancer
           ports:
             - protocol: TCP
             port: 80
             targetPort: 8000
      - kubectl apply -f web-svc-lb.yaml 
        service/web-svc-lb created
        kubectl get pods -n metallb-system
        NAME                        READY   STATUS    RESTARTS   AGE
        controller-fb659dc8-mvffz   1/1     Running   0          23m
        speaker-7t2pp               1/1     Running   0          23m
      - Теперь посмотрите логи пода-контроллера MetalLB (подставьте правильное имя!)
        kubectl --namespace metallb-system logs pod/controller-fb659dc8-mvffz
        {"caller":"service.go:114","event":"ipAllocated","ip":"172.17.255.1","msg":"IP address assigned by controller",
         "service":"default/web-svc-lb","ts":"2021-03-09T09:50:05.986550954Z"}
</pre>

      - Обратите внимание на назначенный IP-адрес (или посмотрите его в выводе kubectl describe svc web-svc-lb)
        $ kubectl describe svc web-svc-lb

<pre>
Name:                     web-svc-lb
Namespace:                default
Labels:                   
Annotations:              
Selector:                 app=web
Type:                     LoadBalancer
IP Families:              
IP:                       10.107.203.71
IPs:                      
LoadBalancer Ingress:     172.17.255.1
Port:                     unset 80/TCP
TargetPort:               8000/TCP
NodePort:                 unset 32068/TCP
Endpoints:                172.17.0.3:8000,172.17.0.4:8000,172.17.0.5:8000
Session Affinity:         None
External Traffic Policy:  Cluster
Events:
  Type    Reason        Age    From                Message
  ----    ------        ----   ----                -------
  Normal  IPAllocated   5m22s  metallb-controller  Assigned IP "172.17.255.1"
  Normal  nodeAssigned  5m21s  metallb-speaker     announcing from node "minikube"
</pre>

      - Если мы попробуем открыть URL http://172.17.255.1/index.html, то... ничего не выйдет.
      - Это потому, что сеть кластера изолирована от нашей основной ОС
        (а ОС не знает ничего о подсети для балансировщиков)
      - Чтобы это поправить, добавим статический маршрут
        - В реальном окружении это решается добавлением нужной подсети на интерфейс сетевого оборудования
        - Или использованием L3-режима (что потребует усилий от сетевиков, но более предпочтительно)
      - Найдите IP-адрес виртуалки с Minikube. Например так:
        minikube ssh
        sudo -i
        ip a show
            inet 192.168.64.2/24 brd 192.168.64.255 scope global dynamic eth0
        P.S. - Самый простой способ найти IP виртуалки с minikube - minikube ip
      - Добавьте маршрут в вашей ОС на IP-адрес Minikube:
        sudo route add 172.17.255.0/24 192.168.64.2
        Password:
        add net 172.17.255.0: gateway 192.168.64.2
      - curl http://172.17.255.1 - успех
   
      - Задание со звездочкой | DNS через MetalLB
        - Сделайте сервис LoadBalancer, который откроет доступ к CoreDNS снаружи кластера (позволит получать записи через внешний IP).
          Например, nslookup web.default.cluster.local 172.17.255.10
        - Поскольку DNS работает по TCP и UDP протоколам - учтите это в конфигурации. 
          Оба протокола должны работать по одному и тому же IP-адресу балансировщика.
        - Полученные манифесты положите в подкаталог ./coredns

<pre>
apiVersion: v1
kind: Service
metadata:
  name: coredns-udp-svc-lb
  namespace: kube-system
  annotations:
    metallb.universe.tf/allow-shared-ip: coredns-ip
spec:
  selector:
    k8s-app: kube-dns
  type: LoadBalancer
  loadBalancerIP: 172.17.255.20
  ports:
    - protocol: UDP
      port: 53
      targetPort: 53

apiVersion: v1
kind: Service
metadata:
  name: coredns-tcp-svc-lb
  namespace: kube-system
  annotations:
    metallb.universe.tf/allow-shared-ip: coredns-ip
spec:
  selector:
    k8s-app: kube-dns
  type: LoadBalancer
  loadBalancerIP: 172.17.255.20
  ports:
    - protocol: TCP
      port: 53
      targetPort: 53
</pre>

        - kubectl apply -f coredns-tcp-svc-lb.yaml
          service/coredns-tcp-svc-lb created
        - kubectl apply -f coredns-udp-svc-lb.yaml
          service/coredns-udp-svc-lb created
        - kubectl get svc -n kube-system

<pre>
NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                  AGE
coredns-tcp-svc-lb   LoadBalancer   10.102.1.112   172.17.255.20   53:31112/TCP             8s
coredns-udp-svc-lb   LoadBalancer   10.99.144.74   172.17.255.20   53:31484/UDP             14s
kube-dns             ClusterIP      10.96.0.10     none            53/UDP,53/TCP,9153/TCP   33h
</pre>

        - nslookup 172.17.255.1 172.17.255.20

<pre>
Server:		172.17.255.20
Address:	172.17.255.20#53
1.255.17.172.in-addr.arpa	name = web-svc-lb.default.svc.cluster.local.
        - nslookup web-svc-lb.default.svc.cluster.local 172.17.255.20
Server:		172.17.255.20
Address:	172.17.255.20#53
Name:	web-svc-lb.default.svc.cluster.local
Address: 10.107.203.71
        - nslookup 172-17-0-4.web-svc-lb.default.svc.cluster.local 172.17.255.20
Server:		172.17.255.20
Address:	172.17.255.20#53
Name:	172-17-0-4.web-svc-lb.default.svc.cluster.local
Address: 172.17.0.4
        - nslookup 172.17.0.4 172.17.255.20
Server:		172.17.255.20
Address:	172.17.255.20#53
4.0.17.172.in-addr.arpa	name = 172-17-0-4.web-svc-cip.default.svc.cluster.local.
4.0.17.172.in-addr.arpa	name = 172-17-0-4.web-svc-lb.default.svc.cluster.local.
</pre>

  - Установка Ingress-контроллера и прокси ingress-nginx
    Создание Ingress
      - Теперь, когда у нас есть балансировщик, можно заняться Ingress- контроллером и прокси:
        - неудобно, когда на каждый Web-сервис надо выделять свой IP-адрес
        - а еще хочется балансировку по HTTP-заголовкам (sticky sessions)
      - Для нашего домашнего задания возьмем почти "коробочный" ingress-nginx от проекта Kubernetes.
        Это "достаточно хороший" Ingress для умеренных нагрузок, основанный на OpenResty и пачке Lua-скриптов.
      - Установка начинается с основного манифеста:  
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml
        - После установки основных компонентов, в инструкции (https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal) 
          рекомендуется применить манифест, который создаст NodePort-сервис.
          Но у нас есть MetalLB, мы можем сделать круче.
        - P.S. Можно сделать просто minikube addons enable ingress, но мы не ищем легких путей
        - Создадим файл nginx-lb.yaml c конфигурацией LoadBalancer-сервиса (работаем в каталоге kubernetes-networks):

<pre>
kind: Service
apiVersion: v1
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  externalTrafficPolicy: Local
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/component: controller
  ports:
    - name: http
      port: 80
      targetPort: http
    - name: https
      port: 443
      targetPort: https
</pre>

        - Теперь применим созданный манифест и посмотрим на IP-адрес, назначенный ему MetalLB
          $ kubectl apply -f nginx-lb.yaml
          service/ingress-nginx created
          $ kubectl get svc -n ingress-nginx

<pre>
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)                      AGE
ingress-nginx                        LoadBalancer   10.105.172.128   172.17.255.2   80:30379/TCP,443:30427/TCP   60s
ingress-nginx-controller             NodePort       10.105.33.253    none           80:30035/TCP,443:31317/TCP   29m
ingress-nginx-controller-admission   ClusterIP      10.102.144.177   none           443/TCP                      29m
</pre>

        - Теперь можно сделать curl на этот IP-адрес
          $ curl http://172.17.255.2 - 404 Not Found
        - Наш Ingress-контроллер не требует ClusterIP для балансировки трафика
        - Список узлов для балансировки заполняется из ресурса Endpoints нужного сервиса 
          (это нужно для "интеллектуальной" балансировки, привязки сессий и т.п.)
        - Поэтому мы можем использовать headless-сервис для нашего веб-приложения.
        - Скопируйте web-svc-cip.yaml в web-svc-headless.yaml
          - измените имя сервиса на web-svc
          - добавьте параметр clusterIP: None

<pre>
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  selector:
    app: web
  type: ClusterIP
  clusterIP: None
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
</pre>

        - Теперь примените полученный манифест и проверьте, что ClusterIP для сервиса web-svc действительно не назначен
          kubectl apply -f web-svc-headless.yaml
          service/web-svc created
          kubectl get svc

<pre>
NAME          TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)        AGE
kubernetes    ClusterIP      10.96.0.1        none           443/TCP        45h
web-svc       ClusterIP      None             none           80/TCP         15s
web-svc-cip   ClusterIP      10.100.124.191   none           80/TCP         35h
web-svc-lb    LoadBalancer   10.107.203.71    172.17.255.1   80:32068/TCP   22h
</pre>

  - Создание правил Ingress
    - Теперь настроим наш ingress-прокси, создав манифест с ресурсом Ingress (файл назовите web-ingress.yaml):

<pre>
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: web
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /web
        backend:
          serviceName: web-svc
          servicePort: 8000
</pre>

    - Примените манифест и проверьте, что корректно заполнены Address и Backends
      kubectl apply -f web-ingress.yaml
      ingress.networking.k8s.io/web created
      kubectl get ingress -o wide
      NAME   CLASS    HOSTS   ADDRESS        PORTS   AGE
      web    <none>   *       192.168.64.2   80      31s
      kubectl describe ingress/web

<pre>
Name:             web
Namespace:        default
Address:          192.168.64.2
Default backend:  default-http-backend:80 (error: endpoints "default-http-backend" not found)
Rules:
  Host        Path  Backends
  ----        ----  --------
  *           
              /web   web-svc:8000 (172.17.0.3:8000,172.17.0.4:8000,172.17.0.5:8000)
Annotations:  nginx.ingress.kubernetes.io/rewrite-target: /
Events:
  Type    Reason  Age                   From                      Message
  ----    ------  ----                  ----                      -------
  Normal  Sync    2m9s (x2 over 2m31s)  nginx-ingress-controller  Scheduled for sync
</pre>

    - Теперь можно проверить, что страничка доступна в браузере
      $ curl http://172.17.255.2/web - работает
      Используется адрес, назначенный ему MetalLB (172.17.255.2), а не minikube (192.168.64.2) (мы же не добавляли нужный аддон)
    - Обратите внимание, что обращения к странице тоже балансируются между Podами. 
      Только сейчас это происходит средствами nginx, а не IPVS


С чистого листа.

Добавьте доступ к kubernetes-dashboard через наш Ingress-прокси:
 - Cервис должен быть доступен через префикс /dashboard)
 - Kubernetes Dashboard должен быть развернут из официального манифеста.
 - Написанные вами манифесты положите в подкаталог ./dashboard

<pre>
$ minikube start --driver=hyperkit --extra-config=kube-proxy.mode=ipvs

$ kubectl get configmap kube-proxy -n kube-system -o yaml | \
  sed -e "s/strictARP: false/strictARP: true/" | \
  kubectl apply -f - -n kube-system

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f metallb-config.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/baremetal/deploy.yaml
kubectl apply -f nginx-lb.yaml

kubectl apply -f dashboard-ingress.yaml:
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: kub-dashboard
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      if ($uri = "/dashboard") { return 302 /dashboard/; }
spec:
  rules:
  - http:
      paths:
      - path: /dashboard(/|$)(.*)
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 443

https://172.17.255.1/dashboard/ - успех.
</pre>

Canary для Ingress  
Реализуйте канареечное развертывание с помощью ingress-nginx:
 - Перенаправление части трафика на выделенную группу подов должно происходить по HTTP-заголовку.
 - Документация: https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/annotations.md#canary
 - Естественно, что вам понадобятся 1-2 "канареечных" пода.
 - Написанные манифесты положите в подкаталог ./canary

<pre>
$ sudo vim sudo vim /private/etc/hosts
  172.17.255.1 nginx-ingress.local

$ kubectl apply -f web-canary-deploy.yaml
$ kubectl apply -f web-canary-svc-headless.yaml
$ kubectl apply -f web-canary-ingress.yaml

apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: web-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "Canary"
    nginx.ingress.kubernetes.io/canary-by-header-value: "is"
spec:
  rules:
  - host: nginx-ingress.local
    http:
      paths:
      - path: /prod
        backend:
          serviceName: web-canary-svc
          servicePort: 8000

$ for i in $(seq 1 10); do curl -s -H "Canary: is" http://nginx-ingress.local/prod | grep HOSTNAME; done
export HOSTNAME='web-canary-fd9589d4b-mp8jm'
export HOSTNAME='web-canary-fd9589d4b-dvlf8'
export HOSTNAME='web-canary-fd9589d4b-mp8jm'
export HOSTNAME='web-canary-fd9589d4b-dvlf8'
export HOSTNAME='web-canary-fd9589d4b-dvlf8'
export HOSTNAME='web-canary-fd9589d4b-mp8jm'
export HOSTNAME='web-canary-fd9589d4b-mp8jm'
export HOSTNAME='web-canary-fd9589d4b-dvlf8'
export HOSTNAME='web-canary-fd9589d4b-dvlf8'
export HOSTNAME='web-canary-fd9589d4b-mp8jm'
$ for i in $(seq 1 10); do curl -s http://nginx-ingress.local/prod | grep HOSTNAME; done
export HOSTNAME='web-6f978c47bc-zr8j7'
export HOSTNAME='web-6f978c47bc-zr8j7'
export HOSTNAME='web-6f978c47bc-tnzkd'
export HOSTNAME='web-6f978c47bc-tnzkd'
export HOSTNAME='web-6f978c47bc-6948b'
export HOSTNAME='web-6f978c47bc-zr8j7'
export HOSTNAME='web-6f978c47bc-tnzkd'
export HOSTNAME='web-6f978c47bc-6948b'
export HOSTNAME='web-6f978c47bc-zr8j7'
export HOSTNAME='web-6f978c47bc-tnzkd'
</pre>


# Kubernetes-volumes

<pre>
$ kind create cluster
Creating cluster "kind" ...
Set kubectl context to "kind-kind"
You can now use your cluster with:
kubectl cluster-info --context kind-kind

$ kubectl cluster-info --context kind-kind
Kubernetes control plane is running at https://127.0.0.1:63779
KubeDNS is running at https://127.0.0.1:63779/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
</pre>

В этом ДЗ мы развернем StatefulSet c MinIO (https://min.io) - локальным S3 хранилищем  

<pre>
minio-statefulset.yaml:
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
spec:
  serviceName: minio
  replicas: 1
  selector:
    matchLabels:
      app: minio # has to match .spec.template.metadata.labels
  template:
    metadata:
      labels:
        app: minio # has to match .spec.selector.matchLabels
    spec:
      containers:
      - name: minio
        env:
        - name: MINIO_ACCESS_KEY
          value: "minio"
        - name: MINIO_SECRET_KEY
          value: "minio123"
        image: minio/minio
        args:
        - server
        - /data 
        ports:
        - containerPort: 9000
        # These volume mounts are persistent. Each pod in the PetSet
        # gets a volume mounted based on this field.
        volumeMounts:
        - name: data
          mountPath: /data
        # Liveness probe detects situations where MinIO server instance
        # is not working properly and needs restart. Kubernetes automatically
        # restarts the pods if liveness checks fail.
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 120
          periodSeconds: 20
  # These are converted to volume claims by the controller
  # and mounted at the paths mentioned above. 
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
</pre>

В результате применения конфигурации должно произойти следующее:
 - Запуститься под с MinIO
 - Создаться PVC
 - Динамически создаться PV на этом PVC с помощью дефолотного StorageClass

<pre>
$ kubectl apply -f minio-statefulset.yaml
statefulset.apps/minio created
$ kubectl get pods                 
NAME      READY   STATUS              RESTARTS   AGE
minio-0   0/1     ContainerCreating   0          8s
$ kubectl get pods
NAME      READY   STATUS    RESTARTS   AGE
minio-0   1/1     Running   0          18s
$ kubectl get pvc 
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-minio-0   Bound    pvc-c0f9d4b7-fe45-4bec-b6ef-b444d5f77cc3   10Gi       RWO            standard       45s
$ kubectl get pv 
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
pvc-c0f9d4b7-fe45-4bec-b6ef-b444d5f77cc3   10Gi       RWO            Delete           Bound    default/data-minio-0   standard                46s
</pre>

Применение Headless Service  
Для того, чтобы наш StatefulSet был доступен изнутри кластера, создадим Headless Service

<pre>
minio-headless-service.yaml:
apiVersion: v1
kind: Service
metadata:
  name: minio
  labels:
    app: minio
spec:
  clusterIP: None
  ports:
    - port: 9000
      name: minio
  selector:
    app: minio

$ kubectl apply -f minio-headless-service.yaml
service/minio created
$ kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
kubernetes   ClusterIP   10.96.0.1    none          443/TCP    36m
minio        ClusterIP   None         none          9000/TCP   8s
$ kubectl get statefulsets.apps -o wide
NAME    READY   AGE   CONTAINERS   IMAGES
minio   1/1     12m   minio        minio/minio
</pre>

Проверка работы MinIO
 - Проверить работу Minio можно с помощью консольного клиента mc (https://github.com/minio/mc)

<pre>
$ brew install minio/stable/mc
$ kubectl port-forward minio-0 9000:9000
$ mc alias set minio http://127.0.0.1:9000 minio minio123
$ mc admin info minio
●  127.0.0.1:9000
   Uptime: 55 minutes 
   Version: 2021-03-12T00:00:47Z
   Network: 1/1 OK 

$ mc mb minio/test
Bucket created successfully `minio/test`.
$ mc ls --summarize minio 
[2021-03-16 15:24:57 EET]     0B test/
Total Size: 0 B
Total Objects: 1
$ mc cp minio-mc-pod.yaml minio/test
$ mc ls --summarize minio/test
[2021-03-16 15:25:35 EET]   203B minio-mc-pod.yaml
Total Size: 203 B
Total Objects: 1
$ mc cat minio/test/minio-mc-pod.yaml
$ mc cp minio/test/minio-mc-pod.yaml mpod.yaml
$ ls -l
total 32
-rw-r--r--@ 1 pit  staff   173 Mar 15 22:16 minio-headless-service.yaml
-rw-r--r--@ 1 pit  staff   203 Mar 16 08:59 minio-mc-pod.yaml
-rw-r--r--@ 1 pit  staff  1430 Mar 16 13:33 minio-statefulset.yaml
-rw-r--r--  1 pit  staff   203 Mar 16 15:27 mpod.yaml
$ mc rm minio/test/minio-mc-pod.yaml
Removing `minio/test/minio-mc-pod.yaml`.
$ mc rb minio/test
Removed `minio/test` successfully.
</pre>

В конфигурации нашего StatefulSet данные указаны в открытом виде, что не безопасно.  
Поместите данные в secrets (https://kubernetes.io/docs/concepts/configuration/secret/)  
и настройте конфигурацию на их использование.

<pre>
$ echo -n 'minio' | base64
bWluaW8=
$ echo -n 'minio123' | base64
bWluaW8xMjM=

minio-secrets.yaml:
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
type: Opaque
data:
  MINIO_ACCESS_KEY: bWluaW8=
  MINIO_SECRET_KEY: bWluaW8xMjM=

В файле StatefulSet делаем замену этого блока
...
        env:
        - name: MINIO_ACCESS_KEY
          value: "minio"
        - name: MINIO_SECRET_KEY
          value: "minio123"
...
на
...
        envFrom:
        - secretRef:
            name: minio-secret
...

$ kubectl apply -f minio-secrets.yaml
secret/minio-secret created
$ kubectl apply -f minio-statefulset-secrets.yaml 
statefulset.apps/minio configured

$ mc admin info minio
●  127.0.0.1:9000
   Uptime: 2 minutes 
   Version: 2021-03-17T02:33:02Z
   Network: 1/1 OK 
</pre>
