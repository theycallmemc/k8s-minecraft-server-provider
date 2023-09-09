from kubernetes import client, config, watch
from kubernetes.client.rest import ApiException

config.load_kube_config()
v1 = client.CoreV1Api()

NAMESPACE = 'default'
POD_LABEL = 'minecraft-server'

def create_pod(name, external_port):
    try:
        pod_manifest = {
            'apiVersion': 'v1',
            'kind': 'Pod',
            'metadata': {'name': name, 'labels': {'app': POD_LABEL}},
            'spec': {
                'containers': [{
                    'name': 'minecraft',
                    'image': 'itzg/minecraft-server',
                    'ports': [{'containerPort': 25565}]
                }]
            }
        }
        
        service_manifest = {
            'apiVersion': 'v1',
            'kind': 'Service',
            'metadata': {'name': name},
            'spec': {
                'selector': {'app': POD_LABEL},
                'ports': [{'port': external_port, 'targetPort': 25565}],
                'type': 'NodePort'
            }
        }

        v1.create_namespaced_pod(NAMESPACE, pod_manifest)
        v1.create_namespaced_service(NAMESPACE, service_manifest)
        print(f"Pod {name} and service created successfully")
    except ApiException as e:
        print(f"Failed to create pod {name}: {e}")

def delete_pod(name):
    try:
        v1.delete_namespaced_pod(name, NAMESPACE)
        v1.delete_namespaced_service(name, NAMESPACE)
        print(f"Pod {name} and service deleted successfully")
    except ApiException as e:
        print(f"Failed to delete pod {name}: {e}")

def watch_pods():
    w = watch.Watch()
    for event in w.stream(v1.list_namespaced_pod, NAMESPACE, label_selector=POD_LABEL):
        pod = event['object']
        name = pod.metadata.name
        if event['type'] == 'ADDED':
            create_pod(name, external_port=30000)  # Set your desired external port here
        elif event['type'] == 'DELETED':
            delete_pod(name)

if __name__ == '__main__':
    watch_pods()