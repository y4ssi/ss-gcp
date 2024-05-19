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

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = "default"
  }

  spec {
    selector = {
      app = "nginx"
    }

    type = "LoadBalancer"

    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "null_resource" "wait_for_external_ip" {
  provisioner "local-exec" {
    command = <<EOT
    for i in {1..30}; do
      gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}
      EXTERNAL_IP=$(kubectl get svc nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      if [ -z "$EXTERNAL_IP" ]; then
        echo "Waiting for external IP..."
        sleep 10
      else
        echo "External IP assigned: $EXTERNAL_IP"
        echo $EXTERNAL_IP > external_ip.txt
        break
      fi
    done
    EOT
  }
  triggers = {
    always_run = "${timestamp()}"
  }

  depends_on = [kubernetes_service.nginx]
}

data "local_file" "external_ip" {
  filename   = "external_ip.txt"
  depends_on = [null_resource.wait_for_external_ip]
}