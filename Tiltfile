load("ext://helm_remote", "helm_remote")
load('ext://namespace', 'namespace_yaml')
def certificate_creation(
    service_name,
):
    build_context="./certificates/"
    service_name_lower = "{}".format(service_name.lower())

    local_resource(
        "{}-certificate-creation".format(service_name_lower),
        'cd {} && pwsh ./generate-certs.ps1'.format(build_context),
        labels=["Local-Certificates"]
    )

def k8s_namespace(
    namespace_name,
    allow_duplicates=False,
    ):

    k8s_yaml(
        namespace_yaml(
            namespace_name,
        ),
        allow_duplicates=allow_duplicates,
    )

def k8s_helm(
    service_name,
    namespace,
    ):

    chart_path = './helm/{}'.format(service_name) or chart_path
    values = './helm/{}/values.yaml'.format(service_name) or values
    release_name = service_name or release_name
    # resource_deps = resource_deps or []

    k8s_yaml(
        helm(
        chart_path,
        values = values,
        namespace=namespace or service_name,
        name=service_name or release_name,
      )
    )

def remote_helm(
    service_name,
    repo_url,
    namespace,
    release_name,
    values,
    ):

    values='helm/{}.yaml'.format(service_name)

    helm_remote(
        repo_name=service_name,
        repo_url=repo_url,
        values=values,
        namespace=namespace or service_name,
        release_name=release_name or service_name,
        chart=service_name
    )

def dotnet_service(
    service_name,
    publish_folder="publish",
    host_port= 80 or None,
    container_port= 80 or None,
    ):

    build_context="../{}".format(service_name)
    dotnet_command="dotnet publish"
    csproj_path = "{}/{}.csproj".format(build_context, service_name)
    dotnet_command_flags="-c Release -o"
    publish_path = "{}/{}".format(build_context, publish_folder)
    service_name_lower = "{}".format(service_name.lower())
    local_resource_name = "{}-build".format(service_name_lower)
    k8s_yaml_path = "{}.yaml".format(service_name_lower)

    local_resource(
        local_resource_name,
        '{} {} {} {}'.format(dotnet_command, csproj_path, dotnet_command_flags, publish_path),
        ignore = ['{}/obj'.format(build_context), '{}/bin'.format(build_context), '{}/.vs'.format(build_context), publish_path],
        deps=['{}'.format(build_context)],
    )
    docker_build(
        service_name_lower,
        publish_path,
        dockerfile='{}/Dockerfile'.format(build_context),
    )
    k8s_yaml(k8s_yaml_path)
    k8s_resource(
        service_name_lower,
        port_forwards="{}:{}".format(host_port, container_port),
        resource_deps=['{}'.format(local_resource_name)],
    )
### Services ###
# Create certificates
certificate_creation('dev')
# Create namespaces
k8s_namespace('database')
k8s_namespace('traefik')
k8s_namespace('cert-manager')
k8s_namespace('rabbitmq')
### Deploy Database ###
### MSSQL ###
k8s_helm(
    service_name = "mssql",
    namespace = "database",
)
## MongoDB ###
# remote_helm(
#     service_name = "mongodb",
#     repo_url = "https://charts.bitnami.com/bitnami",
#     values = ["./helm/mongodb.yaml"],
#     namespace = "database",
#     release_name = "mongodb",
# )
## Traefik
remote_helm(
    service_name = "traefik",
    repo_url = "https://helm.traefik.io/traefik",
    values = "./helm/traefik/values.yaml",
    namespace = "traefik",
    release_name = "traefik",
)
### Cert-Manager ###
# remote_helm(
#     service_name = "cert-manager",
#     repo_url = "https://charts.jetstack.io",
#     values = "./helm/cert-manager.yaml",
#     namespace = "cert-manager",
#     release_name = "cert-manager",
# )
# k8s_yaml('./helm/cluster-issuer.yaml')
# # k8s_yaml('./helm/certificate.yaml')

### RabbitMQ from standard Helm chart ###
# remote_helm(
#     service_name = "rabbitmq",
#     repo_url = "https://charts.bitnami.com/bitnami",
#     values = ["./helm/rabbitmq.yaml"],
#     namespace = "rabbitmq",
#     release_name = "rabbitmq",
# )