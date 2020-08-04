app_name      := sample-spinnaker-service
chart_name    := sample-microservice
git_short_sha := $(shell git rev-parse --short HEAD)

chart_version := $(shell helm show chart $(chart_name) | awk '/version/ { print $$2 }')
chart_path    := $(chart_name)-$(chart_version).tgz
chart_url     := https://artifactory.bettermg.com/artifactory/helm/$(chart_name)/$(chart_path)

image_name          := $(app_name)
image_name_and_tag  := $(image_name):$(git_short_sha)
docker_repo_uri     := artifactory.bettermg.com/docker/$(app_name)
image_repo_uri      := artifactory.bettermg.com/docker/$(image_name_and_tag)
# docker_repo_url     := artifactory.bettermg.com/artifactory/docker/$(app_name)
# image_reference_url := $(docker_repo_url)/$(app_name)/$(git_short_sha)

deploy_helm_chart:
	@echo "Packaging chart $(chart_name)"
	helm package $(chart_name)
	@echo "Deploying $(chart_path) to $(chart_url)"
	curl -u "$(ARTIFACTORY_USER):$(ARTIFACTORY_PASSWORD)" -T $(chart_path) "$(chart_url)"

chart_version:
	@echo $(chart_version)

deploy_docker_image:
	@echo "Building image $(image_name_and_tag)"
	docker build -t $(image_name_and_tag) .
	docker tag $(image_name_and_tag) $(image_repo_uri)
	@echo "Deploying $(image_name_and_tag) to $(image_repo_uri)"
	docker push $(image_repo_uri)

trigger_spinnaker_deploy:
	curl -v -X POST http://localhost:9000/gate/webhooks/webhook/artifactory-helm-docker \
	-H 'Content-Type: application/json' \
	--data \
	'{ \
		"artifacts": [ \
			{ \
				"type": "helm/chart", \
				"name": "$(chart_name)", \
				"reference": "$(chart_url)" \
			}, \
			{ \
				"type": "docker/image", \
				"name": "$(docker_repo_uri)", \
				"reference": "$(image_repo_uri)" \
			} \
		] \
	}'
