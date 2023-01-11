# Red Hat AMQ Streams perf tests

## Pre-requisite

Ensure that the following exists
* Properly configured and working OpenShift Cluster
* Admin Cluster User with ```cluster-admin``` role
* Normal Cluster User

## Create a New Project

As a normal user, create a ```amqstreams``` project:

```bash
oc login -u user
oc new-project amqstreams
```

You may also create the project via the web console by following the instructions [here](https://docs.openshift.com/container-platform/4.3/applications/projects/working-with-projects.html#creating-a-project-using-the-web-console_projects)

## Create Operator Group

To deploy Prometheus and Grafana Operators, we need to first install an OperatorGroup to match the Operator's installation mode and the namespace. This step is describe in [Adding Operators to a cluster](https://docs.openshift.com/container-platform/4.3/operators/olm-adding-operators-to-cluster.html) page from
[OpenShift 4.3 Documentation](https://docs.openshift.com/container-platform/4.3/welcome/index.html) site

```bash
oc login -u admin-user
oc apply -f 01-operator-group.yaml
```

## Deploy Prometheus and Grafana Operators via Web Console

This demo will use [Prometheus Operator](https://operatorhub.io/operator/prometheus) and
[Grafana Operator](https://operatorhub.io/operator/grafana-operator) to deploy them and monitor the AMQ Streams ecosystem easily.

### Login to the Web Console and select the project
1. **Login** to the web console as the `admin-user`
1. **Select** the ```amq-streams-demo``` project (*Home -> Projects -> amq-streams-demo*)

### Installing Prometheus Operator
1. **Naviate** to the OperatorHub (*Operators -> OperatorHub*)
1. **Type** `prometheus` in the *Filter by keyword*
1. **Select** on the `Prometheus Operator`
1. **Review** the Community Operator notice, and **click** `Continue`
1. **Click** Install
1. **Review** the default options, and **click** `Subscribe`

### Installing Grafana Operator
1. **Naviate** to the OperatorHub (*Operators -> OperatorHub*)
1. **Type** `grafana` in the *Filter by keyword*
1. **Select** on the `Grafana Operator`
1. **Review** the Community Operator notice, and **click** `Continue`
1. **Click** Install
1. **Review** the default options, and **click** `Subscribe`

After several minutes we could check these operators are installed and availables:

```bash
$ oc get csv
NAME                        DISPLAY                             VERSION   REPLACES                    PHASE
amqstreams.v2.2.0-4         Red Hat Integration - AMQ Streams   2.2.0-4   amqstreams.v2.2.0-3         Succeeded
grafana-operator.v4.8.0     Grafana Operator                    4.8.0     grafana-operator.v4.7.1     Succeeded
prometheusoperator.0.56.3   Prometheus Operator                 0.56.3    prometheusoperator.0.47.0   Succeeded
```

## Deploy Metrics Platform

Prometheus and Grafana Operator help us to deploy our local Prometheus Server and Grafana instance where
we could manage the metrics from our AMQ Streams Cluster.

Ensure that you're still logged in as the `admin-user` in the correct project:

```bash
oc login -u admin-user
oc project amqstreams
```

### Prometheus Deployment

Deploy a local Prometheus Server as follows:
```bash
oc create secret generic additional-scrape-configs --from-file=conf/prometheus-additional.yml

oc apply -f CR/02-prometheus-metrics
```

A Prometheus instance will be available with a service and a route:

```bash
$ oc get svc
NAME                                                  TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
grafana-operator-controller-manager-metrics-service   ClusterIP   10.217.4.87   <none>        8443/TCP   96m
prometheus                                            ClusterIP   10.217.5.3    <none>        9090/TCP   14s

$ oc get route prometheus -o jsonpath='{.spec.host}'
prometheus-amqstreams.apps-crc.testing
```

The Prometheus Dashboard will look something like this:

![Prometheus Server](./img/prometheus-server.png)

### Grafana Deployment

Deploy Grafana as follows:

```bash
oc apply -f CR/03-grafana.yml
```

Grafana will deploy a Datasource connected to the Prometheus server available by Promtheus in the endpoint ```http://prometheus-operated:9090```. The Grafana Server will use that Datasource to get the metrics. Grafana has a set of dashboards to review the metrics from Apache Zookeeper and AMQ Streams Cluster. 

Setup the Grafana Dashboard:

```bash
oc apply -f CR/04-grafana-dashboard
```

Get the Grafana route:

```bash
oc get route grafana-route -o jsonpath='{.spec.host}'
grafana-route-amqstreams.apps-crc.testing
```

**NOTE:** Use the original credentials **root/secret** as user/password. These credentials are defined in the [Grafana CR](./CR/03-grafana.yaml) file. Also, **wait a few minutes** for Grafan to finish its deployment.

Grafana Dashaboards will be displayed in Grafana as:

![Grafana Dashboards](./img/grafana-dashboards.png)

## Deploy and use a AMQ Streams Cluster

````
oc apply -f CR/05-kafka.yml
````

### Configure topic
````
oc apply -f CR/06-topic.yml
````

### Configure user
````
oc apply -f CR/07-user.yml
````







## Setup client

### Configure keystore

```bash
export DNS_SVC=perf-test-cluster.amqstreams.srv.cluster.local
export KAFKA_SECRET_USER=log-analytics-exporter-kafka-secret

oc get secret $KAFKA_SECRET_USER -n monitoraggio -o jsonpath='{.data.user\.p12}' | base64 --decode > conf/user.p12
oc get secret $KAFKA_SECRET_USER -n monitoraggio -o jsonpath='{.data.user\.password}' | base64 --decode > conf/user.password

export KEYSTORE_NAME=kafka-auth-keystore.jks
export PASSWORD=`cat conf/user.password`

keytool \
    -importkeystore \
    -deststorepass "$PASSWORD" \
    -destkeystore conf/$KEYSTORE_NAME \
    -srckeystore conf/user.p12 \
    -srcstorepass "$PASSWORD" \
    -srcstoretype PKCS12 \
    -ext SAN=DNS:$DNS_SVC
```

### Configure truststore

```bash
export KAFKA_SECRET_CLUSTER=poste-logging-cluster-ca-cert

oc get secret $KAFKA_SECRET_CLUSTER -o jsonpath='{.data.ca\.crt}' | base64 --decode > conf/ca.crt
oc get secret $KAFKA_SECRET_CLUSTER -o jsonpath='{.data.ca\.password}' | base64 --decode > conf/ca.password

export TRUSTSTORE_NAME=kafka-auth-truststore.jks
export PASSWORD=`cat ca.password`

keytool \
  -importcert \
  -deststorepass "$PASSWORD" \
  -alias strimzi-kafka-cert \
  -file conf/ca.crt \
  -keystore conf/$TRUSTSTORE_NAME \
  -keypass "$PASSWORD"
```

### Generate config properties
````bash
cat << EOF > ${PWD}/conf/ssl-perf-test.properties
bootstrap.servers=$DNS_SVC:9093
security.protocol=SSL
ssl.truststore.location=${PWD}/conf/$TRUSTSTORE_NAME
ssl.truststore.password=`cat ${PWD}/conf/ca.password`
ssl.keystore.location=${PWD}/conf/$KEYSTORE_NAME
ssl.keystore.password=`cat ${PWD}/conf/user.password`
ssl.key.password=`cat ${PWD}/conf/user.password`
EOF
````

## Test

### Producer without transactions
````
$KAFKA_HOME/bin/kafka-producer-perf-test.sh \
    --topic ssl-perf-test \
    --throughput -1 \
    --num-records 3000000 \
    --record-size 1024 \
    --producer-props acks=all bootstrap.servers=broker0:9093,broker1:9093,broker2:9093 \
    --producer.config ${PWD}/conf/ssl-perf-test.properties
````

### Producer with transactions


### Producer batch



