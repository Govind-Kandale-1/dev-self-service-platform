REGION        ?= eu-west-1
ENV           ?= prod
TF_DIR        := terraform/environments/$(ENV)
LAMBDA_DIRS   := orchestrator entra grafana update-status notify

.PHONY: bootstrap deploy-infra destroy-infra build-lambdas deploy-lambdas deploy-ui tf-validate ansible-lint test-lambdas clean

bootstrap:
	cd terraform/bootstrap && terraform init && terraform apply -auto-approve

deploy-infra:
	cd $(TF_DIR) && terraform init && terraform apply -auto-approve

destroy-infra:
	cd $(TF_DIR) && terraform destroy -auto-approve

build-lambdas:
	@for dir in $(LAMBDA_DIRS); do \
		echo "Building $$dir..."; \
		cd lambda/$$dir && pip install -r requirements.txt -t package/ -q && \
		cd package && zip -r ../function.zip . -q && cd .. && \
		zip -g function.zip main.py -q && \
		cd ../..; \
	done

deploy-lambdas:
	@for dir in $(LAMBDA_DIRS); do \
		FN=$$(cd $(TF_DIR) && terraform output -raw $${dir//-/_}_function_name 2>/dev/null); \
		if [ -n "$$FN" ]; then \
			echo "Deploying $$dir → $$FN"; \
			aws lambda update-function-code --function-name $$FN \
				--zip-file fileb://lambda/$$dir/function.zip \
				--region $(REGION) --output text --query 'FunctionName'; \
		fi; \
	done

deploy-ui:
	$(eval BUCKET := $(shell cd $(TF_DIR) && terraform output -raw ui_bucket_name))
	$(eval CF_ID  := $(shell cd $(TF_DIR) && terraform output -raw cloudfront_distribution_id))
	aws s3 sync web-ui/ s3://$(BUCKET)/ --delete --region $(REGION)
	aws cloudfront create-invalidation --distribution-id $(CF_ID) --paths "/*"

tf-validate:
	@for dir in $$(find terraform/modules terraform/environments terraform/bootstrap -name "*.tf" -exec dirname {} \; | sort -u); do \
		echo "Validating $$dir..."; \
		terraform -chdir=$$dir init -backend=false -input=false -quiet && \
		terraform -chdir=$$dir validate; \
	done

ansible-lint:
	ansible-lint ansible/

test-lambdas:
	@for dir in $(LAMBDA_DIRS); do \
		if [ -d lambda/$$dir/tests ]; then \
			echo "Testing $$dir..."; \
			cd lambda/$$dir && python -m pytest tests/ -v && cd ../..; \
		fi; \
	done

clean:
	@for dir in $(LAMBDA_DIRS); do \
		rm -rf lambda/$$dir/package lambda/$$dir/function.zip; \
	done
	find . -name "__pycache__" -exec rm -rf {} + 2>/dev/null; true
	find . -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null; true
