# -*- mode: ruby -*-
# # vi: set ft=ruby :

# For help on using kubespray with vagrant, check out docs/vagrant.md

require 'fileutils'

Vagrant.require_version ">= 2.0.0"

CONFIG = File.join(File.dirname(__FILE__), "vagrant/config.rb")

# Uniq disk UUID for libvirt
DISK_UUID = Time.now.utc.to_i

SUPPORTED_OS = {
  "centos7"         => {box: "centos/7", box_version: "2004.01",  user: "vagrant", vmdk_name: "centos-7-1-1.x86_64"}
}

if File.exist?(CONFIG)
  require CONFIG
end

# Defaults for config options defined in CONFIG
$vm_gui ||= false
$vm_memory ||= 2048
$vm_cpus ||= 2
$shared_folders ||= {}
$forwarded_ports ||= {}
$subnet ||= "172.17.8"
$ip_suffix ||= "11"
$os ||= "centos7"
$override_disk_size ||= true
$disk_size ||= 250 * 1024

$boostrap_playbook = "playbook.yml"

host_vars = {}

$box = SUPPORTED_OS[$os][:box]
$box_version = SUPPORTED_OS[$os][:box_version]

# if $inventory is not set, try to use example
$inventory = "inventory" if ! $inventory
$inventory = File.absolute_path($inventory, File.dirname(__FILE__))

# if $inventory has a hosts.ini file use it, otherwise copy over
# vars etc to where vagrant expects dynamic inventory to be
if ! File.exist?(File.join(File.dirname($inventory), "vagrant_ansible_inventory"))
  $vagrant_ansible = File.join(File.dirname(__FILE__), ".vagrant", "provisioners", "ansible")
  FileUtils.mkdir_p($vagrant_ansible) if ! File.exist?($vagrant_ansible)
  if ! File.exist?(File.join($vagrant_ansible,"inventory"))
    FileUtils.ln_s($inventory, File.join($vagrant_ansible,"inventory"))
  end
end

if Vagrant.has_plugin?("vagrant-proxyconf")
    $no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
    (1..$num_instances).each do |i|
        $no_proxy += ",#{$subnet}.#{i+100}"
    end
end

Vagrant.configure("2") do |config|

    $instance_name_prefix = "k8s"
    $instance_name_suffix = "registry"
    config.vm.define vm_name = "%s-%s" % [$instance_name_prefix, $instance_name_suffix] do |config|
        config.vm.box = $box
        config.vm.box_version = $box_version
        
        if SUPPORTED_OS[$os].has_key? :box_url
            config.vm.box_url = SUPPORTED_OS[$os][:box_url]
        end
        config.ssh.username = SUPPORTED_OS[$os][:user]

        # plugin conflict
        if Vagrant.has_plugin?("vagrant-vbguest") then
            config.vbguest.auto_update = false
        end

        # always use Vagrants insecure key
        config.ssh.insert_key = false

        config.vm.provider :virtualbox do |vb|
            vb.memory = $vm_memory
            vb.cpus = $vm_cpus
            vb.name = vm_name
            
            if SUPPORTED_OS[$os].has_key? :vmdk_name
                vmdk_name = SUPPORTED_OS[$os][:vmdk_name]
            end

            unless File.exist?("#{ENV["HOME"]}/VirtualBox VMs/#{vm_name}/#{vm_name}-rootvg_disk01.vmdk")
                vb.customize [ "clonemedium", "disk", "--format", "VMDK",
                    "#{ENV["HOME"]}/VirtualBox VMs/#{vm_name}/#{vmdk_name}.vmdk",
                    "#{ENV["HOME"]}/VirtualBox VMs/#{vm_name}/#{vm_name}-rootvg_disk01.vmdk"
                ]
                vb.customize [ "storageattach", :id, "--storagectl", "IDE", "--port", 0, "--device", 0, "--medium", "none" ]
                vb.customize [ "storagectl", :id, "--remove", "--name", "IDE" ]
                vb.customize [ "closemedium", "disk", "--delete",
                    "#{ENV["HOME"]}/VirtualBox VMs/#{vm_name}/#{vmdk_name}.vmdk"
                ]
                vb.customize [ "storagectl", :id, "--add", "sata", "--name", "SATA", "--controller", "IntelAHCI", "--portcount", "8", "--hostiocache", "on" ]
                vb.customize [ "storageattach", :id, "--storagectl", "SATA", "--port", 0, "--device", 0, "--type", "hdd", "--medium",
                    "#{ENV["HOME"]}/VirtualBox VMs/#{vm_name}/#{vm_name}-rootvg_disk01.vmdk"
                ]
            end

            unless File.exist?("#{ENV["HOME"]}/VirtualBox VMs/#{vm_name}/#{vm_name}-datavg_disk01.vmdk")
                vb.customize [ 'createhd', '--format', 'VMDK', '--size', $disk_size,
                  '--filename', "#{ENV["HOME"]}/VirtualBox VMs/#{vm_name}/#{vm_name}-datavg_disk01.vmdk"
                ]
                vb.customize [ "storageattach", :id, "--storagectl", "SATA", "--port", 1, "--device", 0, "--type", "hdd", "--medium",
                  "#{ENV["HOME"]}/VirtualBox VMs/#{vm_name}/#{vm_name}-datavg_disk01.vmdk"
                ]
            end

        end

        ip = "#{$subnet}.#{$ip_suffix}"
        config.vm.network :private_network, ip: ip
    
        if "x#{ENV['MANAGE_DOCKER']}" == "xfalse"
          $manage_docker = "False"
        end
        if "x#{ENV['DOWNLOAD_ORIGIN']}" == "xfalse"
          $skip_download_origin = "True"
        end
    
        groups_vars = {
          "pypi_server_ip" => ip,
          "innvtble_subnet" => $subnet,
          "manage_docker" => $manage_docker,
          "skip_download_origin" => $skip_download_origin,
        }
    
        host_vars[vm_name] = {
          "ip" => ip,
          "host_fqdn" => "#{$instance_name_prefix}-#{$instance_name_suffix}.internal",
          "local_release_dir" => $local_release_dir,
          "download_run_once" => "False",
          "download_delegate" => "#{$instance_name_prefix}-#{$instance_name_suffix}",
          "bootstrap_os" => SUPPORTED_OS[$os][:bootstrap_os],
          "kubelet_load_modules" => "True",
          "bootstrap_type" => "origin",
          "skip_downloads" => $skip_downloads,
        }

        if "x#{ENV['REGISTRY']}" != "xfalse"
          config.vm.provision "ansible" do |ansible|
            ansible.compatibility_mode = "2.0"
            ansible.playbook = $boostrap_playbook
            if File.exist?(File.join(File.dirname($inventory), "hosts"))
              ansible.inventory_path = $inventory
            end
            ansible.become = true
            ansible.limit = "registry"
            ansible.host_key_checking = false
            ansible.raw_arguments = ["--forks=1", "--flush-cache"]
            ansible.host_vars = host_vars
            #ansible.extra_vars = "_environment.yml"
            #ansible.tags = ['download']
            ansible.groups = {
              "registry" => [vm_name],
    #          "consul-servers:children" => ["kube-registry"],
    #          "kube-registry:vars" => groups_vars,
    #          "etcd" => ["registry"],
    #          "kube-master" => ["registry"],
    #          "vault" => ["registry"],
    #          "kube-node" => ["registry"],
    #          "k8s-cluster:children" => ["registry"]
            }
          end
        end
    
    end
end
