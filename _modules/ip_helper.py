from __future__ import absolute_import
from ipaddress import ip_network

def get_ip_from_range(range, index):
  '''
  Gets an ip address from a CIDR range in the specified index

  range
    (string) - The ip address range in CIDR format (aaa.bbb.ccc.ddd/ee)

  index
    (integer) - The index corresponding to the ip address in the range

  returns
    (string) - The ip address at the index specified.

  example:
    range: 10.254.0.0/16
    index: 1

    returns: 10.254.0.1
  '''
  return str(ip_network(unicode(range))[index])