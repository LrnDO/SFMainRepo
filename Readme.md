Задача полностью сформулирована так:
1. Описание инфраструктуры будущего проекта в виде кода с инструкциями по развертке.
При помощи Terraform и Ansible
Создать три сервера:
два сервера в одном кластере Kubernetes: 1 master и 1 app;
сервер srv для инструментов мониторинга, логирования и сборок контейнеров.
Реализовать возможность установки на сервер всех необходимых нам настроек и пакетов, будь то docker-compose, gitlab-runner или наши публичные ключи для доступа по SSH
2. Сборка и деплой приложения из Git в созданный кластер Kubernetes.
Необходимо склонировать репозиторий к себе в Git (https://github.com/LrnDO/django-pg-docker-app) и настроить пайплайн с этапом сборки образа и отправки его в любой docker registry. Для пайплайнов можно использовать GitLab, Jenkins или GitHub Actions — кому что нравится.
Нужно сделать так, чтобы приложение разворачивалось после сборки в Kubernetes и было доступно по бесплатному домену или на IP-адресе с выбранным портом.
Для деплоя должен использоваться свежесобранный образ. Нужно реализовать сборку из тегов в Git, где тег репозитория в Git будет равен тегу собираемого образа.
3. Настройка мониторинга и логирования. Декомпозиция.
Нужно собирать логи работы пода приложения. Хранить это всё можно либо в самом кластере Kubernetes, либо на srv-сервере.
Выбрать метрики и инструмент, с помощью которого будет отслеживаться состояние приложения: время отклика, сертификат, статус код и так далее. Также нужно знать, когда место на srv-сервере подходит к концу.
Весь мониторинг должен находиться на srv-сервере, чтобы в случае падения кластера мы могли бы узнать об этом.
Ко всему прочему хотелось бы и наблюдать за метриками в разрезе времени. Для этого мы можем использовать Grafana и Zabbix — что больше понравилось.
При желании можно добавить уведомления в любимый мессенджер, погасить кластер и посмотреть на время реакции.

Итак, ниже - само выполнение диплома.

Из папки с терраформом разворачиваю конфиг на свое облако
```
terraform init
terraform validate
terraform plan
terraform apply
```

После развертывания конфигурации машин терраформом, подключаюсь к SRV проверить установку Ansible при помощи 
```
ansible --version
```

Добавляю приватный ключ для доступа к остальным машинам на SRV
```
nano ~/.ssh/id_rsa ---- сюда подсовываю приватный ключ
chmod 0600 ~/.ssh/id_rsa ---- исправляю права доступа
```

Подключаюсь к обоим машинам кластера и выполняю отключение свопа
```
sudo swapoff -a
sudo sed -i '/\sswap\s/ s/^/#/' /etc/fstab
```
Это необходимо для kubelet

Подготавливаю SRV 
```
sudo apt-get update -y
sudo apt-get install -y git python3 python3-venv python3-pip sshpass
```

Копирую дистрибутивы кубспрея
```
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
```
Устанавливаю и изолирую зависимости
```
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

Копирую пример из дистрибутива 
```
cp -rfp inventory/sample inventory/mycluster
```

Исправляю ИП адреса в inventory/mycluster/hosts.yaml на локальные адреса машин в облаке
Проверяю, подключается ли ansible к управляемым машинам при помощи
```
ansible -i inventory/mycluster/hosts.yaml all -m ping
```

Наконец разворачиваю кластер командой
```
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b -v
```
Это займет 20-30 минут.

Устанавливаю kubectl на мою SRV машину для управления кластером
```
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```

Забираю кубконфиг с мастер ноды на сервер SRV, чтобы управлять кластером с него, и меняю адрес сервера с локалхоста на адрес мастерноды
```
scp ubuntu@192.168.10.22:/etc/kubernetes/admin.conf ~/admin.conf
sed -i 's/127.0.0.1/192.168.10.22/' ~/admin.conf
```
Копирую конфиг, чтобы кубцтл работал без переменной KUBECONFIG
```
mkdir -p ~/.kube
cp ./admin.conf ~/.kube/config
```
Проверяю поднят ли кластер командой
```
kubectl get nodes
```
Добавляю Local Path Provisioner для работоспособности PVC у Kubespray 
```
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Для организации CI форкаю себе репу из задания, настраиваю секреты для Github actions и Dockerhub на гитхабе

В .github/workflows создаю docker-build.yml

Сто раз чиню косяки в докерфайле, и пушу его гитхаб, запуская сборку. 

Убеждаюсь, что образ появляется в докерхабе, а затем гитхаб по ссш вламывается на SRV и разворачивает образ на мой кластер k8s

подготавливаю мониторинг - на SRV ставлю докер и докер композ
```
sudo apt update
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
mkdir -p ~/monitoring && cd ~/monitoring
```

Создаю папки для пользователей контейнеров. 65534 для прометеуса, 472 для графаны, 10001 для локи
```
sudo mkdir -p ./data/prometheus
sudo chown -R 65534:65534 ./data/prometheus
sudo chmod -R 775 ./data/prometheus
sudo mkdir -p ./data/grafana
sudo chown -R 472:472 ./data/grafana
sudo chmod -R 775 ./data/grafana
sudo mkdir -p ./data/loki/{compactor,wal,index,chunks,cache}
sudo chown -R 10001:10001 ./data/loki
sudo chmod -R 775 ./data/grafana
```

Поднимаю докер контейнеры на SRV (прометеус, локи, графана и пр)
```
sudo docker-compose up -d
```
Разворачиваю в кубере доп поды с прометеусом и нод экспортером для мониторинга состояния кластера
```
kubectl apply -f monitorin-cluster.yaml
```

Через минут 5 настраиваю в графане дешборды, смотрю логи Джанго, смотрю жив ли Джанго, состояние машины SRV, состояние нодов кластера

УРА
