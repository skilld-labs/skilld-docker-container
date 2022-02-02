

# Used to give a random name to Kubernetes pods executed on the fly by "kubectl run"
RANDOM_STRING ?= $(shell cat /dev/urandom | tr -dc 'a-fA-F0-9' | tr '[:upper:]' '[:lower:]' | fold -w 10 | head -n 1)

IMAGE_HELM=alpine/helm:3.8.0
KUBECTL_IS_INSTALLED := $(shell [ -e "$(shell which kubectl 2> /dev/null)" ] && echo true || echo false)
HELM_IS_INSTALLED := $(shell [ -e "$(shell which helm 2> /dev/null)" ] && echo true || echo false)
JQ_IS_INSTALLED := $(shell [ -e "$(shell which jq 2> /dev/null)" ] || [ -e "$(shell which gojq 2> /dev/null)" ] && echo true || echo false)

# Check if k3s is present, install it if not
lookfork3s:
ifeq ($(KUBECTL_IS_INSTALLED), false)
	@echo "Downloading and installing container orchestrator..."
	curl -sfL https://get.k3s.io | K3S_NODE_NAME=sdc K3S_KUBECONFIG_MODE="644" INSTALL_K3S_VERSION="v1.22.5+k3s1" sh -
	#curl -sfL https://get.k3s.io | K3S_NODE_NAME=sdc K3S_KUBECONFIG_MODE="644" INSTALL_K3S_VERSION="v1.23.3+k3s1" sh -
	@echo
	@echo "- If your command fail here, run it again."
	@echo
endif

install-orchestrator:
	make -s lookfork3s
	for i in {1..50}; do echo "Waiting for default service account..." && kubectl -n default get serviceaccount default -o name &> /dev/null && break || sleep 3; done; echo "Found !"

up:
	if [ $(HELM_IS_INSTALLED) = false ]; then \
		kubectl run "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)" --image=$(IMAGE_HELM) --rm -i --quiet --overrides='{ "kind": "Pod", "apiVersion": "v1", "spec": { "volumes": [ { "name": "host-volume", "hostPath": { "path": "$(CURDIR)", "type": "" } }, { "name": "host-k3s-config", "hostPath": { "path": "/etc/rancher/k3s/k3s.yaml", "type": "" } } ], "containers": [ { "name": "test", "image": "$(IMAGE_HELM)", "command": [ "helm","upgrade","--install","--kubeconfig=/etc/rancher/k3s/k3s.yaml","$(COMPOSE_PROJECT_NAME)","./helm/","--set","projectName=$(COMPOSE_PROJECT_NAME),projectPath=$(CURDIR),imagePhp=$(IMAGE_PHP),imageNginx=$(IMAGE_NGINX),userGroup=$(CGID)" ], "workingDir": "/app", "resources": {}, "volumeMounts": [ { "name": "host-volume", "mountPath": "/app" }, { "name": "host-k3s-config", "mountPath": "/etc/rancher/k3s/k3s.yaml" } ], "terminationMessagePath": "/dev/termination-log", "terminationMessagePolicy": "FallbackToLogsOnError", "imagePullPolicy": "IfNotPresent" } ], "restartPolicy": "Never", "terminationGracePeriodSeconds": 30, "dnsPolicy": "ClusterFirst", "hostNetwork": true, "securityContext": { "runAsUser": $(CUID), "runAsGroup": $(CGID) }, "schedulerName": "default-scheduler", "enableServiceLinks": true }, "status": {} }'; \
		else helm upgrade --install --kubeconfig="/etc/rancher/k3s/k3s.yaml" $(COMPOSE_PROJECT_NAME) ./helm/ --set projectName="$(COMPOSE_PROJECT_NAME)",projectPath="$(CURDIR)",imagePhp="$(IMAGE_PHP)",imageNginx="$(IMAGE_NGINX)",userGroup="$(CGID)"; fi;
	for i in {1..50}; do echo "Waiting for PHP container..." && kubectl exec -it deploy/$(COMPOSE_PROJECT_NAME) -c php -- "whoami" &> /dev/null && break || sleep 3; done; echo "Container is up !"
	$(call php-0, chown -R $(CUID):$(CGID) .)



$(eval PROJECT_IS_UP := $(shell kubectl get deployment $(COMPOSE_PROJECT_NAME) -o go-template='{{ if eq .status.readyReplicas .status.replicas }}{{ "true" }}{{ end }}' 2>/dev/null && echo true || echo false))
# $(eval PROJECT_IS_UP := $(shell [ -e "$(shell kubectl get deploy -l name=$(COMPOSE_PROJECT_NAME) --no-headers=true 2> /dev/null)" ] && echo true || echo false))


SDC_SERVICES=$(shell kubectl get pods -l name=$(COMPOSE_PROJECT_NAME) -o jsonpath="{.items[*].spec.containers[*].name}" 2>/dev/null)

LOCAL_IP = $(shell kubectl get pods -l name=$(COMPOSE_PROJECT_NAME) --template '{{range .items}}{{.status.podIP}}{{"\n"}}{{end}}')

down-containers:
	if [ $(HELM_IS_INSTALLED) = false ]; then kubectl run "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)" --image=$(IMAGE_HELM) --rm -i --quiet --overrides='{ "kind": "Pod", "apiVersion": "v1", "spec": { "volumes": [ { "name": "host-volume", "hostPath": { "path": "$(CURDIR)", "type": "" } }, { "name": "host-k3s-config", "hostPath": { "path": "/etc/rancher/k3s/k3s.yaml", "type": "" } } ], "containers": [ { "name": "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)", "image": "$(IMAGE_HELM)", "command": [ "helm","uninstall","--wait","--kubeconfig=/etc/rancher/k3s/k3s.yaml","$(COMPOSE_PROJECT_NAME)" ], "workingDir": "/app", "resources": {}, "volumeMounts": [ { "name": "host-volume", "mountPath": "/app" }, { "name": "host-k3s-config", "mountPath": "/etc/rancher/k3s/k3s.yaml" } ], "terminationMessagePath": "/dev/termination-log", "terminationMessagePolicy": "FallbackToLogsOnError", "imagePullPolicy": "IfNotPresent" } ], "restartPolicy": "Never", "terminationGracePeriodSeconds": 30, "dnsPolicy": "ClusterFirst", "hostNetwork": true, "securityContext": { "runAsUser": $(CUID), "runAsGroup": $(CGID) }, "schedulerName": "default-scheduler", "enableServiceLinks": true }, "status": {} }'; else helm uninstall --kubeconfig=/etc/rancher/k3s/k3s.yaml --wait $(COMPOSE_PROJECT_NAME); fi;


uninstall-orchestrator:
ifeq ($(KUBECTL_IS_INSTALLED), true)
	/usr/local/bin/k3s-killall.sh
	/usr/local/bin/k3s-uninstall.sh
endif


killall:
ifeq ($(KUBECTL_IS_INSTALLED), true)
	/usr/local/bin/k3s-killall.sh
	/usr/local/bin/k3s-uninstall.sh
endif

# Execute php container as regular user
php = kubectl exec -it deploy/$(COMPOSE_PROJECT_NAME) -c php -- su -s /bin/ash www-data -c "${1}"
# Execute php container as root user
php-0 = kubectl exec -it deploy/$(COMPOSE_PROJECT_NAME) -c php -- ${1}

## Run shell in PHP container as regular user
exec:
	kubectl exec -it deploy/$(COMPOSE_PROJECT_NAME) -c php -- su -s /bin/ash www-data -c ash

## Run shell in PHP container as root
exec0:
	kubectl exec -it deploy/$(COMPOSE_PROJECT_NAME) -c php -- ash

scaffold-list:
	$(eval SCAFFOLD = $(shell kubectl run "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)" --image=$(IMAGE_PHP) --rm -i --quiet --overrides='{ "kind": "Pod", "apiVersion": "v1", "spec": { "volumes": [ { "name": "host-volume", "hostPath": { "path": "$(CURDIR)", "type": "" } } ], "containers": [ { "name": "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)", "image": "$(IMAGE_PHP)", "command": [ "composer", "run-script", "list-scaffold-files" ], "workingDir": "/app", "resources": {}, "volumeMounts": [ { "name": "host-volume", "mountPath": "/app" } ], "terminationMessagePath": "/dev/termination-log", "terminationMessagePolicy": "FallbackToLogsOnError", "imagePullPolicy": "IfNotPresent" } ], "restartPolicy": "Never", "terminationGracePeriodSeconds": 30, "dnsPolicy": "ClusterFirst", "hostNetwork": true, "securityContext": { "runAsUser": $(CUID), "runAsGroup": $(CGID) }, "schedulerName": "default-scheduler", "enableServiceLinks": true }, "status": {} }' | grep -P '^(?!>)'))

logs:
	kubectl logs -f deploy/$(COMPOSE_PROJECT_NAME) --all-containers=true



h:
ifeq ($(HELM_IS_INSTALLED), true)
	@echo "Helm is installed"
else
	@echo "Helm is not installed"
endif


k:
ifeq ($(KUBECTL_IS_INSTALLED), true)
	@echo "Kubernetes is installed"
else
	@echo "Kubernetes is not installed"
endif


j:
ifeq ($(JQ_IS_INSTALLED), true)
	@echo "Jq is installed"
else
	@echo "Jq is not installed"
endif




xxx:
	@echo "im in k3s.mk"




# Convert list of commands to json array format expected by "kubectl run --overrides" commands
jsonarrayconverter = if [ $(JQ_IS_INSTALLED) = false ]; then kubectl run "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)" --image=stedolan/jq --restart=Never --quiet -i --rm --command -- jq -c -n --arg groups "${1}" '$$groups | split(" ")' 2> /dev/null; else jq -c -n --arg groups "${1}" '$$groups | split(" ")'; fi;

# Execute front container function
frontexec = make -s lookfork3s; kubectl run "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)" --image=$(IMAGE_FRONT) --rm -i --quiet --overrides='{ "kind": "Pod", "apiVersion": "v1", "spec": { "volumes": [ { "name": "host-volume", "hostPath": { "path": "$(CURDIR)/web/themes/custom/$(THEME_NAME)" } } ], "containers": [ { "name": "frontexec", "image": "$(IMAGE_FRONT)", "command": $(shell $(call jsonarrayconverter,${1})), "workingDir": "/app", "volumeMounts": [ { "name": "host-volume", "mountPath": "/app" } ], "terminationMessagePolicy": "FallbackToLogsOnError", "imagePullPolicy": "IfNotPresent" } ], "restartPolicy": "Never", "securityContext": { "runAsUser": $(CUID), "runAsGroup": $(CGID) } } }'

# Execute front container function on localhost:FRONT_PORT. Needed for dynamic storybook
frontexec-with-port = make -s lookfork3s; kubectl run "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)" --image=$(IMAGE_FRONT) --rm -i --overrides='{ "kind": "Pod", "apiVersion": "v1", "spec": { "volumes": [ { "name": "host-volume", "hostPath": { "path": "$(CURDIR)/web/themes/custom/$(THEME_NAME)" } } ], "containers": [ { "name": "frontexec-with-port", "image": "$(IMAGE_FRONT)", "command": $(shell $(call jsonarrayconverter,${1})), "stdin": true, "tty": true, "ports": [ { "containerPort": $(FRONT_PORT), "protocol": "TCP" } ], "workingDir": "/app", "volumeMounts": [ { "name": "host-volume", "mountPath": "/app" } ], "terminationMessagePolicy": "FallbackToLogsOnError", "imagePullPolicy": "IfNotPresent" } ], "restartPolicy": "Never", "securityContext": { "runAsUser": $(CUID), "runAsGroup": $(CGID) } } }'

# Execute front container with TTY. Needed for storybook components creation
frontexec-with-interactive = make -s lookfork3s; kubectl run "$(COMPOSE_PROJECT_NAME)-$(RANDOM_STRING)" --image=$(IMAGE_FRONT) --rm -i --overrides='{ "kind": "Pod", "apiVersion": "v1", "spec": { "volumes": [ { "name": "host-volume", "hostPath": { "path": "$(CURDIR)/web/themes/custom/$(THEME_NAME)" } } ], "containers": [ { "name": "frontexec-with-interactive", "image": "$(IMAGE_FRONT)", "command": $(shell $(call jsonarrayconverter,${1})), "stdin": true, "tty": true, "workingDir": "/app", "volumeMounts": [ { "name": "host-volume", "mountPath": "/app" } ], "terminationMessagePolicy": "FallbackToLogsOnError", "imagePullPolicy": "IfNotPresent" } ], "restartPolicy": "Never", "securityContext": { "runAsUser": $(CUID), "runAsGroup": $(CGID) } } }'


