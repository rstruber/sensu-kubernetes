# Overview
This is a general overview for running/demoing Sensu & K8S via Minikube, and an optional component to dump stats from a dummy app to an InfluxDB instance.

## Docker + Kubernetes + Minikube

Here's the workflow I've been using to build docker images locally, and run them using Minikube

### Prerequisites:

- Install Docker for your OS of choice
- Install the [gcloud SDK](https://cloud.google.com/sdk/docs/quickstarts)
  tooling (for access to the `kubectl` cli). Optionally, you can can just install kubectl via the instructions [listed here](https://kubernetes.io/docs/tasks/tools/install-kubectl/) for your OS of choice.
- Install [Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/#install-kubectl)
  _NOTE: The **tl;dr** here is you'll need to install the SDK and run `gcloud
  init` to authenticate, and then `gcloud components install kubectl` to get
  kubectl installed._

### Part 1: Build/Deploy Sensu in a containerized environment
This part assumes you've gone through the prerequisites of setting up Minikube and have it started. If not, do not pass go, do not collect 200 containers. 

Before starting, make sure that minikube is using the docker environment:
```
eval $(minikube docker-env)
```

1. Build a docker image  

    ```
    $ docker build -t sensu:latest docker/sensu/
    ```

2. Run the container locally for testing

    ```
    $ docker run -t sensu:latest /opt/sensu/bin/sensu-client
    ```

    ...and optionally set Sensu Environment Variables to modify the container configuration:   

    ```
    $ docker run -e "SENSU_CLIENT_NAME=docker-client-01" -t sensu:latest /opt/sensu/bin/sensu-client
    ```  

5. Configure some Kubernetes services for our deployment (e.g. loadbalancer):

    ```
    $ cd kubernetes
    $ kubectl create -f sensu-redis-service.yaml
    service "sensu-redis" created
    $ kubectl create -f sensu-server-service.yaml
    service "sensu-server" created
    ```

6. Deploy some configuration files as configmaps:

    ```
    $ kubectl create configmap sensu-client-config --from-file=./configmaps/clients/conf.d/client/
    $ kubectl create configmap sensu-server-config --from-file=./configmaps/servers/conf.d/server/
    $ kubectl create configmap sensu-server-check-config --from-file=./configmaps/servers/conf.d/checks/
    configmap "sensu-server-check-config" created
    $ kubectl create configmap sensu-server-handler-config --from-file=./configmaps/servers/conf.d/handlers/
    ```

7. Deploy Sensu using `kubectl`:

    ```
    $ kubectl create -f sensu-client-deployment.yaml
    $ kubectl create -f sensu-redis-deployment.yaml
    $ kubectl create -f sensu-server-deployment.yaml
    ```

8. Verify the provisioning:

    ```
    $ kubectl get services --watch
    NAME           CLUSTER-IP      EXTERNAL-IP      PORT(S)          AGE
    kubernetes     10.47.240.1     <none>           443/TCP          5d
    sensu-redis    10.47.247.204   <none>           6379/TCP         2d
    sensu-server   10.47.252.108   <pending>   4567:<somerandomport>/TCP   21m
    ```
    
    You should now be able to query the "sensu-server" service to
    hit the Sensu API, as follows:

    ```
    $ curl -s http://192.168.99.100:<somerandomport>/clients
    ```

The instructions above will get you the following:
* Sensu server container (running the api/server services)
* Redis container for use as the transport/datastore
* A set of sensu-clients to demo checks with.
  _NOTE: In practice, we **HIGHLY** recommend using RabbitMQ as the transport instead. 
  This is purely for demo purposes and shouldn't be relied on as a production-ready solution._

If you'd like to see Sensu & Kubernetes in action dumping some pseudo-realistic stats to a TSDB (InfluxDB, in this case), proceed below to 

### Part 2: Spin up a dummy app & InfluxDB instance 

To spin up the Dummy app, head on over to the [README](docker/dummy/README.md), which will cover prerequisites for getting the dummy app, as well as the prometheus collector up and running. For more information about the prometheus collector, see [Portertech's repo](https://github.com/portertech/sensu-prometheus-collector).

For making this a bit more expedient (and presuming you have golang installed):

```
$ cd sensu-kubernetes/docker/dummy
$ go get github.com/gorilla/mux
$ go get github.com/prometheus/client_golang/prometheus/promhttp
$ CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' .
$ docker build -t dummy:latest .
```

The above will build a docker image with a dummy load-balanced application with the sensu-prometheus-exporter binary already in place and ready to send metrics to an InfluxDB instance. 

Once you've created the image, you'll need to set up your Kubernetes service/deployment:

```
$ cd sensu-kubernetes/kubernetes
$ kubectl create -f dummy-backend-service.yaml
$ kubectl create -f dummy-backend-deployment.yaml
```

You should then see your dummy-backend nodes showing up. To get the IP/Port of the Sensu api, you can do:

```
$ minikube service list
|-------------|----------------------|-----------------------------|
|  NAMESPACE  |         NAME         |             URL             |
|-------------|----------------------|-----------------------------|
| default     | dummy-backend        | http://192.168.99.100:32590 |
| default     | kubernetes           | No node port                |
| default     | sensu-enterprise     | http://192.168.99.100:30600 |
| default     | sensu-redis          | No node port                |
| default     | sensu-server         | http://192.168.99.100:32253 |
| kube-system | kube-dns             | No node port                |
| kube-system | kubernetes-dashboard | http://192.168.99.100:30000 |
|-------------|----------------------|-----------------------------|
```

Optionally, you can do `$ minkube service --url sensu-server`, which should return the port mapping similar to the above table.

Why do you need this? Well, the current docker image for Sensu that's been deployed here doesn't include the Uchiwa dashboard. But, you can use say, a [Sensu Vagrant machine](https://github.com/asachs01/sensu-up-and-running) which does include a dashboard to connect to the sensu-api service in your Docker container and see the clients present. 