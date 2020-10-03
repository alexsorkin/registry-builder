PROJECT_VERSION = 0.0.9

DEFAULT_REGISTRY_SERVER = k8s-registry.internal
DEFAULT_REGISTRY_USER = invtable
DEFAULT_REGISTRY_PASS = secret123
DEFAULT_REGISTRY_SECURED = true
DEFAULT_REGISTRY_PORT = 443
DEFAULT_DRY_RUN_MODE = false

BUILD_ARGS =

# Registry server, default k8s-registry.internal
ifneq ($(strip $(REGISTRY_SERVER)),)
  BUILD_ARGS += registry_server: $(REGISTRY_SERVER);
else
  REGISTRY_SERVER = $(DEFAULT_REGISTRY_SERVER)
  BUILD_ARGS += registry_server: $(REGISTRY_SERVER);
endif

# Registry credentials
ifneq ($(strip $(REGISTRY_USER)),)
  BUILD_ARGS += registry_username: $(REGISTRY_USER);
else
  REGISTRY_USER = $(DEFAULT_REGISTRY_USER)
  BUILD_ARGS += registry_username: $(REGISTRY_USER);
endif
ifneq ($(strip $(REGISTRY_PASS)),)
  BUILD_ARGS += registry_password: $(REGISTRY_PASS);
else
  REGISTRY_PASS = $(DEFAULT_REGISTRY_PASS)
  BUILD_ARGS += registry_password: $(REGISTRY_PASS);
endif

# Registry lifecycle parameters
ifneq ($(strip $(REGISTRY_PORT)),)
  BUILD_ARGS += registry_port: $(REGISTRY_PORT);
else
  REGISTRY_PORT = $(DEFAULT_REGISTRY_PORT)
  BUILD_ARGS += registry_port: $(REGISTRY_PORT);
endif
ifeq ($(REGISTRY_SECURED), true)
  BUILD_ARGS += registry_secured: true;
else
  REGISTRY_SECURED = $(DEFAULT_REGISTRY_SECURED)
  BUILD_ARGS += registry_secured: $(REGISTRY_SECURED);
endif
DEBUG_LEVEL =
ifneq ($(strip $(DEBUG_LEVEL)),)
  DEBUG_LEVEL = $(DEBUG_LEVEL)
endif
ifeq ($(strip $(ANSIBLE_USER)),)
  ANSIBLE_USER = vagrant
endif

DRY_RUN_MODE := dry_run_mode: $(DEFAULT_DRY_RUN_MODE)
ifneq ($(strip $(DRY_RUN)),)
  DRY_RUN_MODE := dry_run_mode: $(DRY_RUN)
endif

.PHONY: registry regclean

all: prepare registry

prepare:
	echo "---" > _environment.yml
	echo "$(BUILD_ARGS)"|tr ";" "\n"|sed 's/\ //g'|sed 's/\:/\:\ /g' >> _environment.yml
	echo "$(DRY_RUN_MODE)" >> _environment.yml

registry: prepare
	vagrant up --no-provision
	vagrant provision

provision: prepare
	vagrant provision

status:
	vagrant status

purge:
	vagrant destroy -f

regclean: prepare
	ansible-playbook $(DEBUG_LEVEL) -i inventory/vagrant_ansible_inventory --limit=registry -e "@_environment.yml" cleaner.yaml
