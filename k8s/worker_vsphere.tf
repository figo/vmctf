////////////////////////////////////////////////////////////////////////////////
//                                vSphere                                     //
////////////////////////////////////////////////////////////////////////////////
locals {
  // Static MAC addresses are used for the K8s master and worker nodes
  // in order to keep the network happy while testing.
  //
  // The number of elements in the list must equal or exceed the value
  // of var.worker_count.
  worker_mac_addresses = [
    "00:00:0f:42:1c:d4",
    "00:00:0f:60:ab:c4",
    "00:00:0f:78:89:e4",
  ]
}

resource "vsphere_virtual_machine" "worker_virtual_machine" {
  count = "${var.worker_count}"

  name = "${format(var.worker_vm_name, count.index+1)}"

  resource_pool_id     = "${data.vsphere_resource_pool.resource_pool.id}"
  datastore_id         = "${data.vsphere_datastore.datastore.id}"
  folder               = "${var.vsphere_folder}"
  guest_id             = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type            = "${data.vsphere_virtual_machine.template.scsi_type}"
  num_cpus             = "${var.worker_vm_num_cpu}"
  num_cores_per_socket = "${var.worker_vm_num_cores_per_socket}"
  memory               = "${var.worker_vm_memory}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"

    use_static_mac = true
    mac_address    = "${local.worker_mac_addresses[count.index]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
  }

  vapp {
    properties {
      "guestinfo.coreos.config.data"          = "${base64gzip(data.ignition_config.worker_config.*.rendered[count.index])}"
      "guestinfo.coreos.config.data.encoding" = "gzip+base64"
    }
  }
}
