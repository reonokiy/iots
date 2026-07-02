moved {
  from = libvirt_volume.controlplane_iso
  to   = libvirt_volume.iso["iots-lab-cp-1"]
}

moved {
  from = libvirt_volume.worker_iso
  to   = libvirt_volume.iso["iots-lab-worker-1"]
}

moved {
  from = libvirt_volume.controlplane_disk
  to   = libvirt_volume.disk["iots-lab-cp-1"]
}

moved {
  from = libvirt_volume.worker_disk
  to   = libvirt_volume.disk["iots-lab-worker-1"]
}

moved {
  from = libvirt_domain.controlplane
  to   = libvirt_domain.node["iots-lab-cp-1"]
}

moved {
  from = libvirt_domain.worker
  to   = libvirt_domain.node["iots-lab-worker-1"]
}
