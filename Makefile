PROJECT_VERSION = 0.0.9

DEFAULT_BOOT_REGISTRY_HOST = 172.17.8.11
DEFAULT_BOOT_REGISTRY_USER = innvtable
DEFAULT_BOOT_REGISTRY_PASS = secret123

BUILD_ARGS =

# Registry address, default 172.17.8.11
ifneq ($(strip $(BOOT_REGISTRY)),)
  BUILD_ARGS += boot_registry_address: $(BOOT_REGISTRY);
else
  BOOT_REGISTRY = $(DEFAULT_BOOT_REGISTRY)
  BUILD_ARGS += boot_registry_address: $(BOOT_REGISTRY);
endif

# Registry credentials
ifneq ($(strip $(BOOT_REGISTRY_USER)),)
  BUILD_ARGS += boot_registry_user: $(BOOT_REGISTRY_USER);
else
  BOOT_REGISTRY_USER = $(DEFAULT_BOOT_REGISTRY_USER)
  BUILD_ARGS += boot_registry_user: $(BOOT_REGISTRY_USER);
endif
ifneq ($(strip $(BOOT_REGISTRY_PASS)),)
  BUILD_ARGS += boot_registry_pass: $(BOOT_REGISTRY_PASS);
else
  BOOT_REGISTRY_PASS = $(DEFAULT_BOOT_REGISTRY_PASS)
  BUILD_ARGS += boot_registry_pass: $(BOOT_REGISTRY_PASS);
endif

ifneq ($(strip $(DEBUG_LEVEL)),)
  DEBUG_LEVEL = $(DEBUG_LEVEL);
endif

ifeq ($(strip $(ANSIBLE_USER)),)
  ANSIBLE_USER = vagrant
endif

BUILD_ARGS += ansible_total_nodes: 1; 

.PHONY: registry

all: prepare registry

prepare:
	echo "---" > _environment.yml
	echo "$(BUILD_ARGS)"|tr ";" "\n"|sed 's/\ //g'|sed 's/\:/\:\ /g' >> _environment.yml
	echo  >> _environment.yml

registry: prepare
	vagrant up --no-provision
	vagrant provision

provision:
	vagrant provision

status:
	vagrant status

purge:
	vagrant destroy -f

cleanreg:
	ansible-playbook $(DEBUG_LEVEL) -i inventory/vagrant_ansible_inventory --limit=registry cleaner.yaml
