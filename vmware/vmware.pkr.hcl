packer {
  required_plugins {
    vsphere = {
      version = "~> 1"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

##################################################################################
# VARIABLES
##################################################################################

variable "virtual_machine_password" {
  default     = ""
  description = "Virtual Machine plaintext password to use to authenticate over SSH."
  sensitive   = true
  type        = string
}

variable "vsphere_password" {
  default     = ""
  description = "The plaintext password for authenticating to vCenter."
  sensitive   = true
  type        = string
}

##################################################################################
# LOCALS
##################################################################################

locals {
  buildtime     = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  defaults      = yamldecode(file("${path.root}/defaults.yaml"))
  image         = merge(local.defaults.image, lookup(local.user_yaml, "image", {}))
  shell_scripts = lookup(local.user_yaml, "shell_scripts", [])
  user_yaml     = yamldecode(file("${path.root}/variables.yaml"))
  virtual_machine = merge(local.defaults.virtual_machine, lookup(local.user_yaml, "virtual_machine", {}), {
    network = merge(local.defaults.virtual_machine.network, lookup(lookup(local.user_yaml, "virtual_machine", {}), "network", {}))
    ssh     = merge(local.defaults.virtual_machine.ssh, lookup(lookup(local.user_yaml, "virtual_machine", {}), "ssh", {}))
    storage = merge(local.defaults.virtual_machine.storage, lookup(lookup(local.user_yaml, "virtual_machine", {}), "storage", {}))
  })
  vsphere = merge(local.defaults.vsphere, lookup(local.user_yaml, "vsphere", {}))
}

##################################################################################
# SOURCE
##################################################################################

source "vsphere-iso" "vm" {
  # vCenter Settings
  vcenter_server      = local.vsphere.vcenter
  username            = local.vsphere.username
  password            = var.vsphere_password
  datacenter          = local.vsphere.datacenter
  datastore           = local.vsphere.datastore
  host                = local.vsphere.esx_host
  cluster             = local.vsphere.cluster
  folder              = local.vsphere.template_folder
  insecure_connection = local.vsphere.ignore_certificate
  # IMAGE/ISO Source
  iso_url      = "${local.image.url}"
  iso_checksum = "sha256:${local.image.checksum}"
  # Virtual Machine Settings
  boot_command = [
    "e<down><down><down><end>",
    " autoinstall ds=nocloud;",
    "<F10>"
  ]
  boot_order = "disk,cdrom"
  boot_wait  = local.virtual_machine.boot_wait
  cd_files = [
    "${path.root}/http/meta-data",
    "${path.root}/http/user-data"
  ]
  cd_label               = "cidata"
  cdrom_type             = local.virtual_machine.cdrom_type
  convert_to_template    = true
  CPUs                   = local.virtual_machine.cpu_sockets
  cpu_cores              = local.virtual_machine.cpu_cores
  CPU_hot_plug           = false
  disk_controller_type   = local.virtual_machine.storage.disk_controller_type
  firmware               = local.virtual_machine.firmware
  guest_os_type          = local.virtual_machine.guest_os_type
  http_directory         = "${path.root}/http"
  ip_wait_timeout        = "20m"
  notes                  = "Built by HashiCorp Packer on ${local.buildtime}."
  RAM                    = local.virtual_machine.memory
  RAM_hot_plug           = false
  remove_cdrom           = true
  shutdown_command       = "echo '${var.virtual_machine_password}' | sudo -S -E shutdown -P now"
  shutdown_timeout       = "15m"
  ssh_password           = var.virtual_machine_password
  ssh_username           = local.virtual_machine.username
  ssh_port               = local.virtual_machine.ssh.port
  ssh_timeout            = local.virtual_machine.ssh.timeout
  ssh_handshake_attempts = local.virtual_machine.ssh.handshake_attempts
  tools_upgrade_policy   = true
  vm_name                = local.virtual_machine.name
  vm_version             = local.virtual_machine.version
  storage {
    disk_size             = local.virtual_machine.storage.disk_size
    disk_controller_index = 0
    disk_thin_provisioned = local.virtual_machine.storage.thin_provision
    disk_eagerly_scrub    = local.virtual_machine.storage.disk_eagerly_scrub
  }
  network_adapters {
    network      = local.virtual_machine.network.port_group
    network_card = local.virtual_machine.network.adapter_type
  }
}

##################################################################################
# BUILD
##################################################################################

build {
  sources = [
  "source.vsphere-iso.vm"]
  provisioner "shell" {
    execute_command   = "echo '${var.virtual_machine_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    environment_vars  = ["BUILD_USERNAME=${local.virtual_machine.username}"]
    scripts           = [for s in local.shell_scripts : "${path.root}/scripts/${s}"]
    expect_disconnect = true
  }
}
