#!/bin/bash

if [ $# -eq 0 -o $# -gt 2 ]; then
    echo "Usage: $0 <hostname> [-r]"
    echo "-r      redirect all traffic throgh openvpn"
    exit 1
fi

CERT_HOST=$1
REDIRECT=""

if [ $# -eq 2 -a "$2" == "-r" ]; then
   REDIRECT="redirect-gateway def1" 
fi

TMP_KEY_DIR=/root/manual-keys/${CERT_HOST}-keys

cat <<EOF | ssh -p806 root@vpn-test.measurementlab.net
./generate-cert.sh ${CERT_HOST}
EOF

echo Copying key and certificate to ${CERT_HOST}...
scp -3r -P806 root@vpn-test.measurementlab.net:$TMP_KEY_DIR ${CERT_HOST}:/root/

echo Removing key and certificate from vpn-server...
cat <<EOF | ssh -p806 root@vpn-test.measurementlab.net
rm -fr $TMP_KEY_DIR
EOF

echo Installing openvpn on ${CERT_HOST}
cat <<EOF | ssh ${CERT_HOST}

yum -y install openvpn

mv /root/${CERT_HOST}-keys/${CERT_HOST}.key /etc/openvpn/client.key
chmod 400 /etc/openvpn/client.key
mv /root/${CERT_HOST}-keys/${CERT_HOST}.crt /etc/openvpn/client.crt

rm -fr /root/${CERT_HOST}-keys/

cat <<CEOF >/etc/openvpn/ca.crt
-----BEGIN CERTIFICATE-----
MIIDGTCCAoKgAwIBAgIJAM+qaqjZwWxHMA0GCSqGSIb3DQEBBQUAMGcxCzAJBgNV
BAYTAlVTMQswCQYDVQQIEwJDQTEVMBMGA1UEBxMMU2FuRnJhbmNpc2NvMQ4wDAYD
VQQKEwVNLUxhYjEkMCIGA1UEAxMbdnBuLXRlc3QubWVhc3VyZW1lbnRsYWIubmV0
MB4XDTEzMDMwNTE4MDUwOFoXDTIzMDMwMzE4MDUwOFowZzELMAkGA1UEBhMCVVMx
CzAJBgNVBAgTAkNBMRUwEwYDVQQHEwxTYW5GcmFuY2lzY28xDjAMBgNVBAoTBU0t
TGFiMSQwIgYDVQQDExt2cG4tdGVzdC5tZWFzdXJlbWVudGxhYi5uZXQwgZ8wDQYJ
KoZIhvcNAQEBBQADgY0AMIGJAoGBALDtuqRaqUxIGHbbp9caCMWjrDK+DiRqbZ2k
uH7FG5lYcnjr0QlYS3bmo8qrwOUrQrnWHcXZ7gJtHKT/G06ASEIL/OxpchfBgh12
PhyYA1X48WLE5zFUu1GVZy62Oa2HEBGMvx2Xav4iKdU79k6MZf1ZcTbDq8YKBKwU
qRwX1oOBAgMBAAGjgcwwgckwHQYDVR0OBBYEFMsrwVEPZtJEkT3nt9tdD27xTHZL
MIGZBgNVHSMEgZEwgY6AFMsrwVEPZtJEkT3nt9tdD27xTHZLoWukaTBnMQswCQYD
VQQGEwJVUzELMAkGA1UECBMCQ0ExFTATBgNVBAcTDFNhbkZyYW5jaXNjbzEOMAwG
A1UEChMFTS1MYWIxJDAiBgNVBAMTG3Zwbi10ZXN0Lm1lYXN1cmVtZW50bGFiLm5l
dIIJAM+qaqjZwWxHMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADgYEAYaT/
gLdg/5QxSGpv6QNmrzmed+xc6c8VSALEUtzxTYj+N7wBkorVzyFUDW+H5XHt7PXd
OEg3N8QRwfC9vIssYm4D9FDB4GgOa0Unfz0YvAaguP8pLF3bq8hbHwmOb4YqxYLV
veW13ZpmuKlAkRJCu/647KLeP428KnhPuqdugbg=
-----END CERTIFICATE-----
CEOF

cat <<CEOF >/etc/openvpn/client.conf
##############################################
# Sample client-side OpenVPN 2.0 config file #
# for connecting to multi-client server.     #
#                                            #
# This configuration can be used by multiple #
# clients, however each client should have   #
# its own cert and key files.                #
#                                            #
# On Windows, you might want to rename this  #
# file so it has a .ovpn extension           #
##############################################

# Specify that we are a client and that we
# will be pulling certain config file directives
# from the server.
client

# Use the same setting as you are using on
# the server.
# On most systems, the VPN will not function
# unless you partially or fully disable
# the firewall for the TUN/TAP interface.
;dev tap
dev tun

# Windows needs the TAP-Win32 adapter name
# from the Network Connections panel
# if you have more than one.  On XP SP2,
# you may need to disable the firewall
# for the TAP adapter.
;dev-node MyTap

# Are we connecting to a TCP or
# UDP server?  Use the same setting as
# on the server.
;proto tcp
proto udp

# The hostname/IP and port of the server.
# You can have multiple remote entries
# to load balance between the servers.
;remote my-server-1 1194
remote vpn-test.measurementlab.net 1194
;remote my-server-2 1194

# Choose a random host from the remote
# list for load-balancing.  Otherwise
# try hosts in the order specified.
;remote-random

# Keep trying indefinitely to resolve the
# host name of the OpenVPN server.  Very useful
# on machines which are not permanently connected
# to the internet such as laptops.
resolv-retry infinite

# Most clients don't need to bind to
# a specific local port number.
nobind

# Downgrade privileges after initialization (non-Windows only)
;user nobody
;group nobody

# Try to preserve some state across restarts.
persist-key
persist-tun

# If you are connecting through an
# HTTP proxy to reach the actual OpenVPN
# server, put the proxy server/IP and
# port number here.  See the man page
# if your proxy server requires
# authentication.
;http-proxy-retry # retry on connection failures
;http-proxy [proxy server] [proxy port #]

# Wireless networks often produce a lot
# of duplicate packets.  Set this flag
# to silence duplicate packet warnings.
;mute-replay-warnings

# SSL/TLS parms.
# See the server config file for more
# description.  It's best to use
# a separate .crt/.key file pair
# for each client.  A single ca
# file can be used for all clients.
ca ca.crt
cert client.crt
key client.key

# Verify server certificate by checking
# that the certicate has the nsCertType
# field set to "server".  This is an
# important precaution to protect against
# a potential attack discussed here:
#  http://openvpn.net/howto.html#mitm
#
# To use this feature, you will need to generate
# your server certificates with the nsCertType
# field set to "server".  The build-key-server
# script in the easy-rsa folder will do this.
ns-cert-type server

# If a tls-auth key is used on the server
# then every client must also have the key.
;tls-auth ta.key 1

# Select a cryptographic cipher.
# If the cipher option is used on the server
# then you must also specify it here.
;cipher x

# Enable compression on the VPN link.
# Don't enable this unless it is also
# enabled in the server config file.
comp-lzo

# Set log file verbosity.
verb 3

# Silence repeating messages
;mute 20

;remote my-server-2 1194

$REDIRECT

# Choose a random host from the remote
CEOF

service openvpn start

EOF
