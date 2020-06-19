# quickstart-ec2-ipsec-mesh
## Opportunistic Amazon EC2 IPsec Mesh on the AWS Cloud

This is fork of AW Quickstart with support for Ubuntu 20.04.
To create the IAM role

aws cloudformation create-stack --capabilities CAPABILITY_IAM \
	--capabilities CAPABILITY_NAMED_IAM \
	--stack-name IPsec-mesh
	--template-body file://$(PWD)/templates/ipsec-setup.yaml

Then start and Ubuntu 20.04 instance, choos this IAM role 'IPsec-mesh'.
user-data add the following to start amazon-ssm-agent.

#!/bin/bash
mkdir /tmp/ssm
cd /tmp/ssm
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
sudo dpkg -i amazon-ssm-agent.deb
sudo systemctl enable amazon-ssm-agent

This Cloud formation deploys an opportunistic Internet Protocol Security (IPsec) mesh that sets up dynamic IPsec tunnels between Amazon Elastic Compute Cloud (Amazon EC2) instances in your AWS Web Services (AWS) account. 

The Quick Start is automated by an AWS CloudFormation template that sets up the opportunistic IPsec mesh environment in about 5 minutes. The implementation uses [Libreswan](https://libreswan.org/), an open-source implementation of IPsec encryption and Internet Key Exchange (IKE) version 2.

![Quick Start architecture for opportunistic IPsec mesh on AWS](https://d0.awsstatic.com/partner-network/QuickStart/datasheets/ipsec-mesh-on-aws-architecture.png)

For architectural details, best practices, step-by-step instructions, and customization options, see the 
[deployment guide](https://fwd.aws/8JmD7).
