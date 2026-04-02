variable "project_id" {
  description = "Live GCP project captured by this snapshot"
  type        = string
  default     = "watchmen-test-488807"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "project_owner_email" {
  description = "Current human owner on the project"
  type        = string
  default     = "zagalsky@gmail.com"
}
