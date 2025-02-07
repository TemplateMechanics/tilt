###############################################################################
# LOAD TILT EXTENSIONS (only non-built-in functions)
###############################################################################

load("ext://helm_remote", "helm_remote")
load("ext://namespace", "namespace_yaml")
load("ext://cert_manager", "deploy_cert_manager")
load("ext://git_resource", "git_resource")

###############################################################################
# HELPER FUNCTIONS
###############################################################################

# Create certificates using a local PowerShell script
def certificate_creation(service_name):
    build_context = "./certificates"
    service_name_lower = service_name.lower()
    local_resource(
        "{}-certificate-creation".format(service_name_lower),
        "cd {} && sudo pwsh ./generate-certs.ps1".format(build_context),
        labels=["Local-Certificates"],
    )

    local_resource(
        "{}-edge-certificate-install".format(service_name_lower),
        "cd {} && kubectl delete secret wildcard-tls-dev --ignore-not-found -n traefik && kubectl create secret tls wildcard-tls-dev -n traefik --key ./intermediateCA/private/localhost.key.pem --cert ./intermediateCA/certs/localhost-chain.cert.pem".format(build_context),
        deps=["{}-certificate-creation".format(service_name_lower), "k8s_namespace"],
        labels=["Local-Certificates"]
    )

def install_flux(service_name):
    local_resource(
        "{}-flux-install".format(service_name),
        "flux install",
        deps=["k8s_namespace"],
        labels=["Flux"]
    )

# Create a Kubernetes namespace using a YAML snippet from the namespace extension
def k8s_namespace(namespace_name, allow_duplicates=False):
    k8s_yaml(
        namespace_yaml(namespace_name),
        allow_duplicates=allow_duplicates,
    )

# Deploy a Helm chart that lives in your local helm/ folder
def k8s_helm(service_name, namespace):
    chart_path = "./helm/{}".format(service_name)
    values_path = "./helm/{}/values.yaml".format(service_name)
    k8s_yaml(
        helm(
            chart_path,
            values=values_path,
            namespace=namespace,
            name=service_name,
        )
    )

# Deploy a Helm chart using Kustomize and optionally generate a local HTTPS link for the resource
def k8s_kustomize(path_to_dir, service_name, generate_link=False, flags=[]):
    # Deploy the Kustomize resource
    kustomized_yaml = kustomize(path_to_dir, flags=flags)
    k8s_yaml(kustomized_yaml)

    # If generate_link is enabled, construct and print the local HTTPS service URL
    if generate_link:
        service_url = "https://{}.localhost".format(service_name)
        print("Kustomize Deployment Completed for {}: {}".format(service_name, service_url))
        
        # Create a local Tilt resource for the link
        local_resource(
            "{}".format(service_name),
            cmd="echo 'Service available at {}'".format(service_url),
            links=[service_url],  # Attach the link so it appears in the UI
            labels=["Flux"]
        )

        return service_url  # Return the link for potential use elsewhere
    else:
        print("Kustomize Deployment Completed for {} (no link required).".format(service_name))
        return None  # No link needed

# Deploy a remote Helm chart from a given repository URL
def remote_helm(service_name, repo_url, namespace, release_name, values):
    helm_remote(
        repo_name=service_name,
        repo_url=repo_url,
        values=values,  # a string or a list of values files
        namespace=namespace,
        release_name=release_name,
        chart=service_name,
    )

# Build and deploy a .NET service
def dotnet_service(
    service_name,
    publish_folder="publish",
    host_port=80,
    container_port=80,
):
    build_context = "../{}".format(service_name)
    csproj_path = "{}/{}.csproj".format(build_context, service_name)
    publish_path = "{}/{}".format(build_context, publish_folder)
    service_name_lower = service_name.lower()
    local_resource_name = "{}-build".format(service_name_lower)
    k8s_yaml_path = "{}.yaml".format(service_name_lower)

    # Build the .NET project locally
    local_resource(
        local_resource_name,
        "dotnet publish {} -c Release -o {}".format(csproj_path, publish_path),
        ignore=[
            "{}/obj".format(build_context),
            "{}/bin".format(build_context),
            "{}/.vs".format(build_context),
            publish_path,
        ],
        deps=[build_context],
    )

    # Build the Docker image from the published output
    docker_build(
        service_name_lower,
        publish_path,
        dockerfile="{}/Dockerfile".format(build_context),
    )

    # Deploy the Kubernetes manifests
    k8s_yaml(k8s_yaml_path)
    k8s_resource(
        service_name_lower,
        port_forwards="{}:{}".format(host_port, container_port),
        resource_deps=[local_resource_name],
    )

# Manage Git repositories using the git_resource extension.
def checkout_git_resource(name, repo_url, ref="master", subpath=None):
    git_resource(
        name=name,
        repo=repo_url,
        ref=ref,
        subpath=subpath,
    )
            
###############################################################################
# EXAMPLE USAGE
###############################################################################
# Create Kubernetes namespaces
k8s_namespace("database")
k8s_namespace("flux")
k8s_namespace("traefik")

# Create certificates via a local script (if applicable)
certificate_creation("dev")

# Install Flux
install_flux("dev")

# Deploy services
# Deploy a local Helm chart (for example, MSSQL)
k8s_helm(
    service_name="mssql",
    namespace="database",
)

# Deploy a remote Helm chart (for example, Traefik)
remote_helm(
    service_name="traefik",
    repo_url="https://helm.traefik.io/traefik",
    values="./helm/traefik.yaml",
    namespace="traefik",
    release_name="traefik",
)

# Deploy Kustomized Helm resources with selective link generation
k8s_kustomize("./helm/bitnami/", "bitnami", generate_link=False)
k8s_kustomize("./helm/jupyterhub/", "jupyterhub", generate_link=True)
k8s_kustomize("./helm/jenkins/", "jenkins", generate_link=True)
k8s_kustomize("./helm/harbor/", "harbor", generate_link=True)
k8s_kustomize("./helm/kyverno/", "kyverno", generate_link=False)
k8s_kustomize("./helm/keycloak/", "auth", generate_link=True)
k8s_kustomize("./helm/policy-reporter/", "policy-reporter", generate_link=False)
k8s_kustomize("./helm/wordpress/", "wordpress", generate_link=True)

# Deploy a .NET service:
# dotnet_service("MyDotnetService", publish_folder="publish", host_port=8080, container_port=80)
