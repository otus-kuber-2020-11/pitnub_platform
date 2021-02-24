# pitnub_platform
pitnub Platform repository

# Оглавление
# [Kubernetes-intro](#kubernetes-intro)
# [Kubernetes-controllers](#kubernetes-controllers)

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

