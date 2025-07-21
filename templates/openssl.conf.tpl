[ req ]
default_bits       = 2048
prompt             = no
default_md         = sha256
req_extensions     = req_ext
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
C  = US
ST = California
L  = Campbell
O  = Mirantis
OU = Testing Team
CN = ${msr_common_name}

[ req_ext ]
subjectAltName = @alt_names

[ v3_ext ]
authorityKeyIdentifier = keyid,issuer
basicConstraints       = CA:FALSE
keyUsage               = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage       = serverAuth
subjectKeyIdentifier   = hash
subjectAltName         = @alt_names

[ alt_names ]
DNS.1 = ${msr_common_name}
