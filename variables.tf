variable "project_id" {
  description = "The ID of the GCP project"
  type        = string
}

variable "region" {
  description = "The region to deploy the GKE cluster"
  type        = string
  default     = "us-central1"
}

variable "min_node_count" {
  description = "The minimum number of nodes in the GKE node group."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "The maximum number of nodes in the GKE node group."
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "The type of machine to use for nodes in the GKE node group."
  type        = string
  default     = "e2-medium"
}
