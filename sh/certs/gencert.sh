#!/bin/bash

ROOT='.'
CA_NAME='hf.ca.sb'               # Should fit with openssl.cnf ca name (line 2)
CONFIG_FILE=$ROOT'/openssl.cnf'
CA_FILE_PATH=$ROOT'/'$CA_NAME
CA_KEY_FILE=$CA_FILE_PATH'.key'
CA_CRT_FILE=$CA_FILE_PATH'.crt'
CA_SUBJECT="/C=CA/ST=Qc/L=Quebec/O=My Org/OU=My Org Department/CN=My Org CA"
DB_FILE_PATH=$ROOT'/hf.srv.db.hf'
DB_KEY_FILE=$DB_FILE_PATH'.key'
DB_CSR_FILE=$DB_FILE_PATH'.csr'
DB_CRT_FILE=$DB_FILE_PATH'.crt'
DB_SUBJECT="/C=CA/ST=Qc/L=Quebec/O=My Org/OU=My Org Department/CN=db.hf"
CLI_NAMES=('player' 'flagupdater' 'web' 'owner')  # Must match with database users

mkdir -p $CA_FILE_PATH
touch $ROOT'/'$CA_NAME'.db'
touch $ROOT'/'$CA_NAME'.crl.srl'
echo "21" > $ROOT'/'$CA_NAME'.crt.srl'
echo "" >> $ROOT'/'$CA_NAME'.crt.srl'
rm $CA_CRT_FILE
rm $CA_KEY_FILE

# Generate CA and self-sign
openssl req -new -x509 -nodes \
    -config $CONFIG_FILE \
    -keyout $CA_KEY_FILE \
    -out $CA_CRT_FILE \
    -subj "$CA_SUBJECT" \
    -extensions ca_ext
openssl x509 -in $CA_CRT_FILE -text

# Generate and sign DB server cert
openssl req -new -nodes \
    -config $CONFIG_FILE \
    -keyout $DB_KEY_FILE \
    -out $DB_CSR_FILE \
    -subj "$DB_SUBJECT"
openssl ca -batch \
    -config $CONFIG_FILE \
    -in $DB_CSR_FILE \
    -out $DB_CRT_FILE \
    -extensions server_reqext
openssl x509 -in $DB_CRT_FILE -text

# Generate and sign client certs
for name in "${CLI_NAMES[@]}"
do
    FILE_PATH=$ROOT'/'$name
    KEY_FILE=$FILE_PATH'.key'
    CSR_FILE=$FILE_PATH'.csr'
    CRT_FILE=$FILE_PATH'.crt'

    openssl req -new -nodes \
        -config $CONFIG_FILE \
        -keyout $KEY_FILE \
        -out $CSR_FILE \
        -subj "/C=CA/ST=Qc/L=Quebec/O=My Org/OU=My Org Department/CN=$name" 
    openssl ca -batch \
        -config $CONFIG_FILE \
        -in $CSR_FILE \
        -out $CRT_FILE \
        -extensions client_reqext
    openssl x509 -in $CRT_FILE -text

    # tmp
    mv $KEY_FILE 'cli.psql.scoreboard.'$name'.key'
    mv $CSR_FILE 'cli.psql.scoreboard.'$name'.csr'
    mv $CRT_FILE 'cli.psql.scoreboard.'$name'.crt'
done
