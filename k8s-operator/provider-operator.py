import kubernetes.client as client
import kubernetes.config as config
import kubernetes.watch as watch
import yaml

# Load Kubernetes configuration
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
    except Exception as e:
        print(f"Failed to create pod {name}: {e}")

def delete_pod(name):
    try:
        v1.delete_namespaced_pod(name, NAMESPACE)
        v1.delete_namespaced_service(name, NAMESPACE)
        print(f"Pod {name} and service deleted successfully")
    except Exception as e:
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

def apply_crd_from_yaml(file_path):
    try:
        api_instance = client.ApiextensionsV1Api()

        with open(file_path, "r") as crd_file:
            crd_manifest = yaml.safe_load(crd_file)
            api_instance.create_custom_resource_definition(body=crd_manifest)

        print("CRD created successfully.")

    except Exception as e:
        print(f"Exception when creating CRD: {e}")

if __name__ == '__main__':
    crd_yaml_file = "./minecraft-crd.yaml"
    apply_crd_from_yaml(crd_yaml_file)
    watch_pods()
