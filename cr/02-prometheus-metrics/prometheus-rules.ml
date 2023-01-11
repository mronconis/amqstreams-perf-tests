apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    role: alert-rules
    app: strimzi
  name: prometheus-k8s-rules
spec:
  groups:
  - name: kafka
    rules:
    - alert: KafkaRunningOutOfSpace
      expr: kubelet_volume_stats_available_bytes{kubernetes_pod_name=~"([a-z]+-)+kafka-[0-9]+"} < 5368709120
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Kafka is running out of free disk space'
        description: 'There are only {{ $value }} bytes available at {{ $labels.persistentvolumeclaim }} PVC'
    - alert: UnderReplicatedPartitions
      expr: kafka_server_replicamanager_underreplicatedpartitions > 0
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Kafka under replicated partitions'
        description: 'There are {{ $value }} under replicated partitions on {{ $labels.kubernetes_pod_name }}'
    - alert: AbnormalControllerState
      expr: sum(kafka_controller_kafkacontroller_activecontrollercount) != 1
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Kafka abnormal controller state'
        description: 'There are {{ $value }} active controllers in the cluster'
    - alert: OfflinePartitions
      expr: sum(kafka_controller_kafkacontroller_offlinepartitionscount) > 0
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Kafka offline partitions'
        description: 'One or more partitions have no leader'
    - alert: UnderMinIsrPartitionCount
      expr: kafka_server_replicamanager_underminisrpartitioncount > 0
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Kafka under min ISR partitions'
        description: 'There are {{ $value }} partitions under the min ISR on {{ $labels.kubernetes_pod_name }}'
    - alert: OfflineLogDirectoryCount
      expr: kafka_log_logmanager_offlinelogdirectorycount > 0
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Kafka offline log directories'
        description: 'There are {{ $value }} offline log directories on {{ $labels.kubernetes_pod_name }}'
    - alert: ScrapeProblem
      expr: up{job="kubernetes-services",kubernetes_namespace!~"openshift-.+",kubernetes_pod_name=~".+-kafka-[0-9]+"} == 0
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'Prometheus unable to scrape metrics from {{ $labels.kubernetes_pod_name }}/{{ $labels.instance }}'
        description: 'Prometheus was unable to scrape metrics from {{ $labels.kubernetes_pod_name }}/{{ $labels.instance }} for more than 3 minutes'
    - alert: ClusterOperatorContainerDown
      expr: count((container_last_seen{container_name="strimzi-cluster-operator"} > (time() - 90))) < 1 or absent(container_last_seen{container_name="strimzi-cluster-operator"})
      for: 1m
      labels:
        severity: major
      annotations:
        summary: 'Cluster Operator down'
        description: 'The Cluster Operator has been down for longer than 90 seconds'
    - alert: KafkaBrokerContainersDown
      expr: absent(container_last_seen{container_name="kafka",kubernetes_pod_name=~".+-kafka-[0-9]+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'All `kafka` containers down or in CrashLookBackOff status'
        description: 'All `kafka` containers have been down or in CrashLookBackOff status for 3 minutes'
    - alert: KafkaTlsSidecarContainersDown
      expr: absent(container_last_seen{container_name="tls-sidecar",kubernetes_pod_name=~".+-kafka-[0-9]+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'All `tls-sidecar` containers in the Kafka pods are down or in CrashLookBackOff status'
        description: 'All `tls-sidecar` containers in the Kafka pods are down or in CrashLookBackOff status for 3 minutes'
    - alert: KafkaContainerRestartedInTheLast5Minutes
      expr: count(count_over_time(container_last_seen{container_name="kafka"}[5m])) > 2 * count(container_last_seen{container_name="kafka",kubernetes_pod_name=~".+-kafka-[0-9]+"})
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: 'One or more Kafka containers restarted too often'
        description: 'One or more Kafka containers were restarted too often within the last 5 minutes'
  - name: zookeeper
    rules:
    - alert: AvgRequestLatency
      expr: zookeeper_avgrequestlatency > 10
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Zookeeper average request latency'
        description: 'The average request latency is {{ $value }} on {{ $labels.kubernetes_pod_name }}'
    - alert: OutstandingRequests
      expr: zookeeper_outstandingrequests > 10
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Zookeeper outstanding requests'
        description: 'There are {{ $value }} outstanding requests on {{ $labels.kubernetes_pod_name }}'
    - alert: ZookeeperRunningOutOfSpace
      expr: kubelet_volume_stats_available_bytes{kubernetes_pod_name=~"([a-z]+-)+zookeeper-[0-9]+"} < 5368709120
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Zookeeper is running out of free disk space'
        description: 'There are only {{ $value }} bytes available at {{ $labels.persistentvolumeclaim }} PVC'
    - alert: ZookeeperContainerRestartedInTheLast5Minutes
      expr: count(count_over_time(container_last_seen{container_name="zookeeper"}[5m])) > 2 * count(container_last_seen{container_name="zookeeper",kubernetes_pod_name=~".+-zookeeper-[0-9]+"})
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: 'One or more Zookeeper containers were restarted too often'
        description: 'One or more Zookeeper containers were restarted too often within the last 5 minutes. This alert can be ignored when the Zookeeper cluster is scaling up'
    - alert: ZookeeperContainersDown
      expr: absent(container_last_seen{container_name="zookeeper",kubernetes_pod_name=~".+-zookeeper-[0-9]+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'All `zookeeper` containers in the Zookeeper pods down or in CrashLookBackOff status'
        description: 'All `zookeeper` containers in the Zookeeper pods have been down or in CrashLookBackOff status for 3 minutes'
    - alert: ZookeeperTlsSidecarContainersDown
      expr: absent(container_last_seen{container_name="tls-sidecar",kubernetes_pod_name=~".+-zookeeper-[0-9]+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'All `tls-sidecar` containers in the Zookeeper pods down or in CrashLookBackOff status'
        description: 'All `tls-sidecar` containers in the Zookeeper pods have been down or in CrashLookBackOff status for 3 minutes'
  - name: entityOperator
    rules:
    - alert: TopicOperatorContainerDown
      expr: absent(container_last_seen{container_name="topic-operator",kubernetes_pod_name=~".+-entity-operator-.+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'Container topic-operator in Entity Operator pod down or in CrashLookBackOff status'
        description: 'Container topic-operator in Entity Operator pod has been or in CrashLookBackOff status for 3 minutes'
    - alert: UserOperatorContainerDown
      expr: absent(container_last_seen{container_name="user-operator",kubernetes_pod_name=~".+-entity-operator-.+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'Container user-operator in Entity Operator pod down or in CrashLookBackOff status'
        description: 'Container user-operator in Entity Operator pod have been down or in CrashLookBackOff status for 3 minutes'
    - alert: EntityOperatorTlsSidecarContainerDown
      expr: absent(container_last_seen{container_name="tls-sidecar",kubernetes_pod_name=~".+-entity-operator-.+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'Container tls-sidecar Entity Operator pod down or in CrashLookBackOff status'
        description: 'Container tls-sidecar in Entity Operator pod have been down or in CrashLookBackOff status for 3 minutes'
  - name: connect
    rules:
    - alert: ConnectContainersDown
      expr: absent(container_last_seen{container_name=~".+-connect",kubernetes_pod_name=~".+-connect-.+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'All Kafka Connect containers down or in CrashLookBackOff status'
        description: 'All Kafka Connect containers have been down or in CrashLookBackOff status for 3 minutes'
  - name: bridge
    rules:
    - alert: BridgeContainersDown
      expr: absent(container_last_seen{container_name=~".+-bridge",kubernetes_pod_name=~".+-bridge-.+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'All Kafka Bridge containers down or in CrashLookBackOff status'
        description: 'All Kafka Bridge containers have been down or in CrashLookBackOff status for 3 minutes'
  - name: mirrorMaker
    rules:
    - alert: MirrorMakerContainerDown
      expr: absent(container_last_seen{container_name=~".+-mirror-maker",kubernetes_pod_name=~".+-mirror-maker-.+"})
      for: 3m
      labels:
        severity: major
      annotations:
        summary: 'All Kafka Mirror Maker containers down or in CrashLookBackOff status'
        description: 'All Kafka Mirror Maker containers have been down or in CrashLookBackOff status for 3 minutes'
  - name: kafkaExporter
    rules:
    - alert: UnderReplicatedPartition
      expr: kafka_topic_partition_under_replicated_partition > 0
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Topic has under-replicated partitions'
        description: 'Topic  {{ $labels.topic }} has {{ $value }} under-replicated partition {{ $labels.partition }}'
    - alert: TooLargeConsumerGroupLag
      expr: kafka_consumergroup_lag > 1000
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'Consumer group lag is too big'
        description: 'Consumer group {{ $labels.consumergroup}} lag is too big ({{ $value }}) on topic {{ $labels.topic }}/partition {{ $labels.partition }}'
    - alert: NoMessageForTooLong
      expr: changes(kafka_topic_partition_current_offset{topic!="__consumer_offsets"}[10m]) == 0
      for: 10s
      labels:
        severity: warning
      annotations:
        summary: 'No message for 10 minutes'
        description: 'There is no messages in topic {{ $labels.topic}}/partition {{ $labels.partition }} for 10 minutes'