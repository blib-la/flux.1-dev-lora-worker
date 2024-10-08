variable "DOCKERHUB_REPO" {
  default = "timpietruskyblibla"
}

variable "DOCKERHUB_IMG" {
  default = "flux-1-dev-lora-worker"
}

variable "RELEASE_VERSION" {
  default = "latest"
}

group "default" {
  targets = ["development", "production"]
}

target "development" {
  context = "."
  dockerfile = "Dockerfile"
  args = {
    ENVIRONMENT = "development"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}-dev"]
}

target "production" {
  context = "."
  dockerfile = "Dockerfile"
  args = {
    ENVIRONMENT = "production"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}"]
}
