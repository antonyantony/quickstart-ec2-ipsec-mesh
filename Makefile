ZIPS += functions/packages/enroll_cert_lambda_function/enroll_cert_lambda_function.zip
ZIPS += functions/packages/generate_certifcate_lambda_function/generate_certifcate_lambda_function.zip
ZIPS += functions/packages/ipsec_setup_lambda_function/ipsec_setup_lambda_function.zip

PWD ?= $(shell pwd)
STACK_NAME ?= "ec2-ipsec-mesh""

.PHONY: zips
zips:
	rm -f $(ZIPS)
	zip functions/packages/enroll_cert_lambda_function/enroll_cert_lambda_function.zip functions/source/enroll_cert_lambda_function/enroll_cert_lambda_function.py
	zip functions/packages/generate_certifcate_lambda_function/generate_certifcate_lambda_function.zip functions/source/generate_certifcate_lambda_function/generate_certifcate_lambda_function.py
	zip functions/packages/ipsec_setup_lambda_function/ipsec_setup_lambda_function.zip functions/source/ipsec_setup_lambda_function/ipsec_setup_lambda_function.py

.PHONY: wait_stack_create
wait_stack_create:
	echo "Wait for the stack '$@' creation to finish"
	@aws cloudformation wait stack-create-complete --stack-name $<

.PHONY: iam
iam:
	aws cloudformation create-stack --capabilities CAPABILITY_IAM \
		--capabilities CAPABILITY_NAMED_IAM \
		--stack-name $(STACK_NAME) \
		--template-body file://$(PWD)/templates/ipsec-setup.yaml
	$(MAKE) wait_stack_create,$(STACK_NAME))

.PHONY: instance
instance:
	aws cloudformation create-stack --stack-name $(INSTANCE_NAE) \
		--parameters ParameterKey=ParentVPCStack,ParameterValue=ec2-network-benchmark-vpc \
		--template-body file://$(PWD)/ipsec-mesh-instance.yaml \
