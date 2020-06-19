#!/bin/bash
# 
#	
#   Enrolls certificate,installs and setups ipsec
#
#  Variable needed	
#		configBucket		- Config Bucket name. The keys (files names) are predefines: 
#		oe-conf.conf   		- configration of the oppurtonistic ipsec
#	       	private 		- list of networks with mandaqtory protection
#		clear			- list of netowrks to communication without encryption	
#		installCert.py		- script to enroll certifcates
#		cronIPSecStats.sh	- srcript that collects statistics
#		cron.txt		- cron job definition
#		generateCertbundleLambda - Lambda name for the certifcate generation. 
#
# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0#
##

set -u

# put here the bucket and lambda name 
configBucket="{{configBucket}}"
certificate='{{certificate}}'
certificate_only='{{certificate_only}}'


install_certificate () {

	region=`curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | cut -f 4 -d '"'`

	echo $certificate | ./jq  .CERT_P12_B64 | base64 -i -d > ./cert.p12
	if [ $? -ne 0 ]; then
		echo "Error: Failed to extract certifcate from variable"
		exit 10 
	fi

	echo $certificate | ./jq  .CERT_P12_ENCRYPTED_PWD  |  base64 -i -d > ./tmp
	password=`aws kms decrypt --ciphertext-blob fileb://tmp --region "$region" | ./jq .Plaintext | base64 -d -i | tr -d '"'`
	if [ $? -ne 0 ]; then
		echo "Error: Failed to decrypt the password"
		exit 11 
	fi
	rm ./tmp

	NSS_DB_DIR=${NSS_DB_DIR-'/etc/ipsec.d'}

        rm -fr ${NSS_DB_DIR}/*db

    	ipsec initnss

	pk12util -i ./cert.p12 -d sql:${NSS_DB_DIR} -W "$password"
	if [ $? -ne 0 ]; then
		echo "Error: Failed to install certifcate"
		exit 5
	fi
	rm -fr ./cert.p12
	echo "certificate installed successful"

	local_ipv4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

	if [ -n "${local_ipv4}" ]; then
		inet_addr=$(ip addr | grep "$local_ipv4")
		if [ -n "${inet_addr}" ]; then
			set $inet_addr
			ipmask=$2
			echo "add ${ipmask} to /etc/ipsec.d/policies/private"
			echo ${ipmask} >> /etc/ipsec.d/policies/private
		fi
	fi

	grep nameserver /etc/resolv.conf | while read -r line ;
	do
		set ${line};
		ns=$2;
		echo "add nameserver ${ns}/32 to /etc/ipsec.d/policies/clear"
		echo "${ns}/32" >> /etc/ipsec.d/policies/clear;
	done
	ip route show default | while read -r line ;
	do
		set $line;
		gw=$3
		echo "add default gateway ${gw}/32 to /etc/ipsec.d/policies/clear"
		echo "${gw}/32" >> /etc/ipsec.d/policies/clear
	done
}

install_ubuntu_essentials () {
	sudo apt-get -qq update -y
	sudo apt install -qq -y python3-pip jq
	sudo apt install -qq -y awscli
	pip >/dev/null 2>/dev/null || alias pip=pip3
	NSS_DB_DIR=/var/lib/ipsec/nss
}

apt_install () {
	sudo apt-get -qq update -y
	sudo apt-get -qq install -y libreswan
}

# config and files will be stored in folder /root/ipsec 
cd /root
mkdir ipsec || echo "ignorre"  
cd ipsec


if [ $certificate_only == "true" ]; then
	install_certificate
	#sudo ipsec restart
	exit 0
fi 

apt-get -v >/dev/null 2>/dev/null && install_ubuntu_essentials

pip --version || curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && sudo python get-pip.py
curl https://stedolan.github.io/jq/download/linux64/jq > jq && chmod 755 jq 
aws --version || sudo pip install boto3 awscli 
if [ $? -ne 0 ]; then 
	echo "Error: (PIP, boto3 or awscli) can not be installed"
	exit 1
fi 

apt-get -v >/dev/null 2>/dev/null
if [ $? -eq 0 ]; then
	apt_install
else
	sudo yum -y install libreswan curl
fi

if [ $? -ne 0 ]; then 
	echo "Error: (Libreswan or curl) can not be installed"
	exit 2
fi

# download ipsec policies
aws s3 cp "s3://$configBucket/config/private" . && \
aws s3 cp "s3://$configBucket/config/private-or-clear" . && \
aws s3 cp "s3://$configBucket/config/clear-or-private" . && \
aws s3 cp "s3://$configBucket/config/clear" . && \
aws s3 cp "s3://$configBucket/config/oe-cert.conf" . && \
if [ $? -ne 0 ]; then
	echo "Error: Failed to download configs from s3://$configBucket files: oe-cert.conf, private, clear "
	exit 4
fi

# download the ipsec statistics
aws s3 cp "s3://$configBucket/sources/cronIPSecStats.sh" . && \
aws s3 cp "s3://$configBucket/sources/cron.txt" .
if [ $? -ne 0 ]; then
	echo "Error: Failed to download IPSec stats scripts from s3://$configBucket files: cronIPSecStats.sh and cron.txt "
	exit 9
fi

# copy policy to ipsec folder
sudo cp private /etc/ipsec.d/policies/private && \
sudo cp private-or-clear /etc/ipsec.d/policies/private-or-clear && \
sudo cp clear-or-private /etc/ipsec.d/policies/clear-or-private && \
sudo cp clear /etc/ipsec.d/policies/clear && \
sudo cp oe-cert.conf /etc/ipsec.d/oe-cert.conf
if [ $? -ne 0 ]; then
	echo "Error: Failed to copy localy files: oe-cert.conf, private, clear "
	exit 6
fi

# enroll certificate 
install_certificate
sudo ipsec restart
if [ $? -ne 0 ]; then
	echo "Error: Failed to restart ipsec"
	exit 7 
fi

i=`curl http://169.254.169.254/latest/meta-data/instance-id`
sed -i.bak "s/INSTANCE/$i/" cronIPSecStats.sh 
chmod 755 cronIPSecStats.sh
# install statistics with cronjob
sudo crontab ./cron.txt
if [ $? -ne 0 ]; then
	echo "Error: Failed to install cron job"
	exit 8 
fi
