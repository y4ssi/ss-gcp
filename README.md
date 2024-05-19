# Terraform GKE Cluster Setup

This repository contains Terraform code to create a Google Kubernetes Engine (GKE) cluster with a dedicated VPC, and deploy an Nginx deployment with pod anti-affinity and a public LoadBalancer service. Additionally, it includes the necessary configuration for Nginx to display pod information using environment variables and a `ConfigMap`.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)

## Setup

### 1. Install Terraform

Follow the installation instructions for Terraform at: [Terraform Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli).

### 2. Install kubectl

Follow the installation instructions for kubectl at: [Install and Set Up kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).

### 3. Install Google Cloud SDK

Follow the installation instructions for Google Cloud SDK at: [Google Cloud SDK Installation](https://cloud.google.com/sdk/docs/install).

### 4. Authenticate with Google Cloud

Authenticate with your Google Cloud account using the following command:

```sh
gcloud auth login
```

Set the project you want to use:

```sh
gcloud config set project YOUR_PROJECT_ID
```

### 5. Clone this repository

Clone this repository to your local machine:

```sh
git clone https://github.com/y4ssi/ss-gcp.git
cd ss-gcp
```

### 6. Create a `terraform.tfvars` file

Create a `terraform.tfvars` file in the project directory with the following content:

```hcl
project_id = "your-project-id"
region     = "us-central1"
```

Note: `us-central1` is just an example

### 7. Initialize Terraform

Initialize Terraform to install the necessary providers:

```sh
terraform init
```

### 8. Apply the Terraform configuration

Review and apply the Terraform configuration to create the GKE cluster and deploy Nginx:

```sh
terraform apply
```

### 9. Configure kubectl to use the new cluster

Get the credentials for the new GKE cluster:

```sh
gcloud container clusters get-credentials ss-gke-cluster --region us-central1 --project $(gcloud config get-value project)
```

Note: `us-central1` is just an example

### 10. Get the external IP of the Nginx service

The external IP of the Nginx service will be automatically printed in the Terraform output. To manually retrieve it, use the following command:

```sh
terraform output nginx_service_external_ip
```

## Cleanup

To destroy the resources created by Terraform, run:

```sh
terraform destroy
```

## Test the web-server

```sh
curl http://$(terraform output nginx_service_external_ip | awk 'NR == 2')
```

Example of the response:

```sh
Pod Name: nginx-deployment-6666c5fc7d-45vk9
Pod IP: 10.124.5.6
Pod Namespace: default
```

## Notes

- The created GKE cluster does not have autoscaling enabled.
- The Nginx deployment ensures that there is a maximum of one pod per node.
- The Nginx service is publicly accessible via an external IP provided by the LoadBalancer.

## ConfigMap and Nginx Configuration

A `ConfigMap` is created to pass environment variables and configure Nginx to display pod information. The `ConfigMap` and deployment configuration are included in the `web-server.tf` file as follows:

```hcl
resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name      = "nginx-config"
    namespace = "default"
  }

  data = {
    "nginx.conf" = <<-EOT
      env POD_NAME;
      env POD_IP;
      env POD_NAMESPACE;
      env NODE_NAME;
      events {
        worker_connections 1024;
      }
      http {
        server {
          listen 80;
          location / {
            default_type text/plain;
            content_by_lua_block {
              local pod_name = os.getenv("POD_NAME")
              local pod_ip = os.getenv("POD_IP")
              local pod_namespace = os.getenv("POD_NAMESPACE")
              local node_name = os.getenv("NODE_NAME")
              ngx.say("Pod Name: ", pod_name)
              ngx.say("Pod IP: ", pod_ip)
              ngx.say("Pod Namespace: ", pod_namespace)
              ngx.say("Node Name: ", node_name)
            }
          }
        }
      }
    EOT
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = "default"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app"
                  operator = "In"
                  values   = ["nginx"]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        container {
          name  = "nginx"
          image = "openresty/openresty:latest"

          port {
            container_port = 80
          }
          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          volume_mount {
            name       = "nginx-config-volume"
            mount_path = "/usr/local/openresty/nginx/conf/nginx.conf"
            sub_path   = "nginx.conf"
          }
        }

        volume {
          name = "nginx-config-volume"

          config_map {
            name = kubernetes_config_map.nginx_config.metadata[0].name
          }
        }
      }
    }
  }
}
```

This `ConfigMap` and deployment configuration ensure that Nginx displays the pod name, IP, and namespace.
