from __future__ import absolute_import
from shutil import rmtree
import os

def stop_kubelet():
  '''
  stops the kubelet service so that any relevant containers can be removed without them
  being automatically restarted by the kubelet
  '''
  return __salt__['cmd.run']('service kubelet stop')

def start_kubelet():
  '''
  starts the kubelet service
  '''
  return __salt__['cmd.run']('service kubelet start')

def remove_etcd_containers():
  '''
  Removes the etcd and etcd related containers. Currently, that's the containers
  with names that start:
  k8s_POD_etcd-server
  k8s_etcd-server
  k8s_POD_etcd-server-events
  k8s_etcd-server-events
  k8s_POD_kube-api
  k8s_kube-api

  basically, removes the etcd, etcd-events, and kube-apiserver pods and containers
  '''

  # build the filter list
  docker_command = ("docker ps -q " +
                     "-f 'name=k8s_etcd' " +
                     "-f 'name=k8s_POD_etcd' " +
                     "-f 'name=k8s_kube-api' " +
                     "-f 'name=k8s_POD_kube-api'")
  
  # Get the list of running containers that need to be stopped and removed
  containers_to_stop_and_remove = __salt__['cmd.run'](docker_command)
  containers_to_stop_and_remove = " ".join(containers_to_stop_and_remove.split('\n'))

  # stop containers first
  stop_result = __salt__['cmd.run']('docker stop ' + containers_to_stop_and_remove)

  # remove containers
  remove_result = __salt__['cmd.run']('docker rm ' + containers_to_stop_and_remove)

  return ("===== Stopping etcd containers =====\n" + stop_result + 
          "\n\n===== Removing etcd ontainers =====\n" + remove_result)

def delete_old_etcd_data(path='/mnt/master-pd'):
  '''
  Deletes the old etcd data stored on the host. This is typically stored in the
  /mnt/master-pd directory

  CAUTION: This is destructive and will delete the contents of the folder passed to it

  path
    (String) - optional - path to delete
  '''
  if os.path.exists(path):
    return rmtree(path)

  return "old data not present"

def cp_etcd_snapshot_files(snapshot_dir='salt://kubernetes/etcd/restore/', dest='/mnt/etcd'):
  '''
  Will copy the etcd snapshot files from somewhere on the salt fs to the targetted host

  CAUTION: This will delete the contents of the destination directory!

  copies two files:
  snapshot.db
  snapshot-events.db

  snapshot_dir
    (String) - optional - the salt fs path to the directory where the etcd snapshot restore files are
  dest
    (String) - optional - the destination directory where the snapshot files should be placed
  '''
  if os.path.exists(dest):
    rmtree(dest)

  os.makedirs(dest)

  results = {}
  for snapshot in ['snapshot.db', 'snapshot-events.db']:
    results[snapshot] = __salt__['cp.get_file'](snapshot_dir + snapshot, 
                                                dest + "/" + snapshot)

  return results

def restore_etcd(host_ip=None, etcd_protocol="http", server_port="2380", etcd_members="", 
                 snapshot_dir='/mnt/etcd'):
  '''
  restores the etcd and etcd-events databases from snapshots

  NOTE: by default, this relies heavily on mine and pillar data. MAKE SURE YOUR
  MINE AND PILLAR DATA ARE UP TO DATE BEFORE RUNNING THIS

  host_ip
    (String) - optional - the ip address of the host this is being run on. defaults
    to discovering this information from grain and pillar data.
  etcd_protocol
    (String) - optional - the protocol used for etcd communication (either http or https)
  server_port
    (String) - optional - the etcd port to use
  etcd_members
    (String) - optional - a comma separated list of etcd member addresses in the 
    following example format:
    hostname-1=http://123.45.67.89:1234,hostname-2=http://123.45.67.90:1234
  snapshot_dir
    (String) - optional - The local directory where the etcd snapshot files can
    be found
  '''
  if etcd_members == "":
    cluster_name = __salt__['pillar.get']("kubernetes:k8s_env", "default")
    master_ips = __salt__['pillar.get']("kubernetes:master_ips", None)
    if master_ips is None:
      master_ips = __salt__['mine.get']('I@kubernetes:master and I@kubernetes:k8s_env:' + cluster_name, 
                                        'network.internal_ip', 'compound')

      if master_ips is not None:
        master_ips = master_ips.values()

    members = []
    for ip in master_ips:
      members.append('etcd-' + ip.replace('.','-') + '=' + 
                       etcd_protocol +'://' + ip + ':' + str(server_port))

    etcd_members = ",".join(members)

  if host_ip is None:
    bind_iface = __salt__['pillar.get']("bind_iface", "eth0")
    host_ip = __salt__['grains.get']("ip_interfaces").get(bind_iface)[0]

  result = {}
  for suffix in ["", "-events"]:
    etcd_restore_command = (
      "etcdctl snapshot restore " + snapshot_dir + "/snapshot" + suffix + ".db"
      " --name etcd-" + host_ip.replace('.', '-') +
      " --initial-advertise-peer-urls " + etcd_protocol + "://" + host_ip + ":" + str(server_port) +
      " --data-dir /mnt/master-pd/var/etcd/data" + suffix +
      " --initial-cluster-token etcd-server" + suffix +
      " --initial-cluster " + etcd_members)

    # result["command" + suffix] = etcd_restore_command
    result["snapshot" + suffix] = __salt__['cmd.run'](etcd_restore_command, env=[{'ETCDCTL_API':'3'}])

  return result

def end_to_end_etcd_restore(old_data_path='/mnt/master-pd', 
                            snapshot_src='salt://kubernetes/etcd/restore/',
                            snapshot_dst='/mnt/etcd/',
                            host_ip=None, etcd_protocol="http", 
                            server_port="2380", etcd_members=""):
  '''
  Does the end to end restore, which includes:
  1. stopping the kubelet
  2. removing the etcd containers
  3. deleting the old etcd data
  4. copying the snapshot files from salt fs
  5. restoring etcd

  NOTE: you must then restart the kubelet to finish the process

  old_data_path
    (String) - optional - the path where the old etcd data is stored
    CAUTION: This directory and contents will be REMOVED
  snapshot_src
    (String) - optional - the salt fs source directory where the etcd snapshot 
    files are located
  snapshot_dst
    (String) - optional - the destination for the etcd snapshot files on the
    local host
  host_ip
    (String) - optional - the ip address of the host this is being run on. defaults
    to discovering this information from grain and pillar data.
  etcd_protocol
    (String) - optional - the protocol used for etcd communication (either http or https)
  server_port
    (String) - optional - the etcd port to use
  etcd_members
    (String) - optional - a comma separated list of etcd member addresses in the 
    following example format:
    hostname-1=http://123.45.67.89:1234,hostname-2=http://123.45.67.90:1234
  '''
  results = {}
  results['1-stop_kubelet'] = stop_kubelet()
  results['2-remove_etcd_containers'] = remove_etcd_containers()
  results['3-delete_old_etcd_data'] = delete_old_etcd_data(old_data_path)
  results['4-cp_etcd_snapshot_files'] = cp_etcd_snapshot_files(snapshot_src, snapshot_dst)
  results['5-restore_etcd'] = restore_etcd(host_ip, etcd_protocol, server_port, etcd_members, snapshot_dst)

  return results