from __future__ import absolute_import
import datetime
import os
from shutil import rmtree

# Import 3rd Party Libs
try:
    import M2Crypto
    HAS_M2 = True
except ImportError:
    HAS_M2 = False

def generate_certs(cluster_tag="default", api_service_address="10.254.0.1", 
                   api_server_fqdn="kubernetes.api", force_regen=False):
  '''  
  Generates a new set of certificate key pairs to be used by kubernetes.

  This places all the generated certificates into the following folder:
  /var/salt/k8s-helper/pki/<cluster_tag>/

  The following files should be generated
  ca.key - the CA private key
  ca.crt - the CA certificate
  server.key - the kubernetes system private key
  server.csr - the kubernetes system certificate signing request
  server.ca - the kubernetes system certificate signed by the ca
  kubecfg.key - the kubernetes client access private key
  kubecfg.csr - the kubernetes client access certificate signing request
  kubecfg.crt - the kubernetes client access certificate signed by the ca

  PRE-REQUISITES
    you need the M2Crypto library in order to generate certificates using the 
    x509 salt module. On Ubuntu, you can install this using apt-get:
    apt-get install python-dev python-m2crypto

  cluster_tag
    (string) - The cluster_tag to identify which cluster these certificates are
    being generated for

  api_service_address
    (string) - The ip address corresponding to the kubernetes' api-server service
    address

  api_server_fqdn
    (string) - The fqdn assigned to the api-server for this cluster

  force_regen
    (boolean) - If true, will delete the contents of the folder where the
    certificates and keys will be placed if it exists so that new keys can be
    generated.

  returns
    (String) - A list of the results for each file generated.
  '''
  
  if not HAS_M2:
    return ("You must install M2Crypto in order to generate certificates " +
            "using the x509 module. In Ubuntu, you can run the following " + 
            "command:\n" +
            "apt-get install python-dev python-m2crypto")

  # Path where the certificates will be placed
  pki_path = "/var/salt/k8s-helper/pki/" + cluster_tag + "/"

  if not os.path.exists(pki_path):
    os.makedirs(pki_path)
  else:
    if not force_regen:
      return ("Certificate directory: " + pki_path + 
              "\nDirectory exists already! set force_regen to True to " +
              "force certificate regeneration")
    else:
      rmtree(pki_path)
      os.makedirs(pki_path)

  # arguments for creating ca.key
  ca_private_args = {
    "fun": "x509.create_private_key",
    "path": pki_path + "ca.key"
  }

  # arguments for creating ca.crt
  ca_cert_args = {
    "fun": "x509.create_certificate",
    "path": pki_path + "ca.crt",
    "CN": api_service_address + "@" + datetime.datetime.now().strftime('%Y%m%d%H%M%S'),
    "signing_private_key": pki_path + "ca.key",
    "subjectKeyIdentifier": "hash",
    "basicConstraints": "CA:TRUE",
    "keyUsage": "Certificate Sign, CRL Sign",
    "authorityKeyIdentifier": "keyid"
  }

  # arguments for creating server.key
  server_private_args = {
    "fun": "x509.create_private_key",
    "path": pki_path + "server.key"
  }

  # arguments for creating server.csr
  server_csr_args = {
    "fun": "x509.create_csr",
    "path": pki_path + "server.csr",
    "private_key": pki_path + "server.key"
  }

  # arguments for creating server.crt
  server_cert_args = {
    "fun": "x509.create_certificate",
    "path": pki_path + "server.crt",
    "CN": "kubernetes-master",
    "csr": pki_path + "server.csr",
    "signing_private_key": pki_path + "ca.key",
    "signing_cert": pki_path + "ca.crt",
    "subjectKeyIdentifier": "hash",
    "basicConstraints": "CA:FALSE",
    "keyUsage": "Digital Signature, Key Encipherment",
    "authorityKeyIdentifier": "keyid",
    "extendedKeyUsage": "TLS Web Server Authentication",
    "subjectAltName": "IP Address:" + api_service_address + 
                      ", DNS:kubernetes, DNS:kubernetes.default, " +
                      "DNS:kubernetes.default.svc, " +
                      "DNS:kubernetes.default.svc.cluster.local, " + 
                      "DNS:" + api_server_fqdn
  }

  # arguments for creating kubecfg.key
  kubecfg_private_args = {
    "fun": "x509.create_private_key",
    "path": pki_path + "kubecfg.key"
  }

  # arguments for creating kubecfg.csr
  kubecfg_csr_args = {
    "fun": "x509.create_csr",
    "path": pki_path + "kubecfg.csr",
    "private_key": pki_path + "kubecfg.key"
  }

  # arguments for creating kubecfg.crt
  kubecfg_cert_args = {
    "fun": "x509.create_certificate",
    "path": pki_path + "kubecfg.crt",
    "CN": "kubecfg",
    "O": "system:masters",
    "csr": pki_path + "kubecfg.csr",
    "signing_private_key": pki_path + "ca.key",
    "signing_cert": pki_path + "ca.crt",
    "subjectKeyIdentifier": "hash",
    "basicConstraints": "CA:FALSE",
    "keyUsage": "Digital Signature",
    "authorityKeyIdentifier": "keyid",
    "extendedKeyUsage": "TLS Web Client Authentication"
  }

  results = []

  # Run the commands that generate the certs
  for args in [ca_private_args, ca_cert_args, server_private_args, 
               server_csr_args, server_cert_args, kubecfg_private_args, 
               kubecfg_csr_args, kubecfg_cert_args]:
    results.append(__salt__['salt.cmd'](**args))

  return results