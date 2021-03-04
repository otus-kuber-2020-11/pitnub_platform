# pitnub_platform
pitnub Platform repository

## Оглавление
### [ДЗ Kubernetes-intro](#kubernetes-intro)
### [ДЗ Kubernetes-controllers](#kubernetes-controllers)
### [ДЗ Kubernetes-security](#kubernetes-security)


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

