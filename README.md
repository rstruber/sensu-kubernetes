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
    configmap "sensu-client-config" created
    $ kubectl create configmap sensu-server-config --from-file=./configmaps/servers/conf.d/server/
    configmap "sensu-server-config" created
    $ kubectl create configmap sensu-server-check-config --from-file=./configmaps/servers/conf.d/checks/
    configmap "sensu-server-check-config" created
    $ kubectl create configmap sensu-server-handler-config --from-file=./configmaps/servers/conf.d/handlers/
    configmap "sensu-server-handler-config" created
    $ kubectl create configmap sensu-server-filter-config --from-file=./configmaps/servers/conf.d/filters/
    configmap "sensu-server-filter-config" created
    ```

7. Deploy Sensu using `kubectl`:

    ```
    $ kubectl create -f sensu-redis-deployment.yaml
    deployment "sensu-redis-deployment" created
    $ kubectl create -f sensu-server-deployment.yaml
    deployment "sensu-server-deployment" created
    ```

8. Verify the provisioning:

    ```
    $ kubectl get services --watch
    NAME           CLUSTER-IP      EXTERNAL-IP      PORT(S)          AGE
    kubernetes     10.47.240.1     <none>           443/TCP          5d
    sensu-redis    10.47.247.204   <none>           6379/TCP         2d
    sensu-server   10.47.252.108   <pending>   4567:<somerandomport>/TCP   21m
    ```

    You should now be able to query the "sensu-server" service "EXTERNAL-IP" to
    hit the Sensu API, as follows:

    ```
    $ curl -s http://104.197.74.159:4567/clients
    ```

The instructions above will get you the following:
* Sensu server container (running the api/server services)
* Redis container for use as the transport/datastore
  _NOTE: In practice, we **HIGHLY** recommend using RabbitMQ as the transport instead. This is purely for demo purposes and shouldn't be relied on as a production-ready solution._\

If you'd like to see Sensu & Kubernetes in action dumping some pseudo-realistic stats to a TSDB (InfluxDB, in this case), proceed below to 

### Part 2: Spin up a dummy app & InfluxDB instance 