.PHONY: help install server clickhouse clickhouse-prod clickhouse-stop postgres postgres-client postgres-prod postgres-stop

require = \
	  $(foreach 1,$1,$(__require))
__require = \
	    $(if $(value $1),, \
	    $(error Provide required parameter: $1$(if $(value 2), ($(strip $2)))))

help:
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

install: ## Run the initial setup
	mix deps.get
	mix ecto.create
	mix ecto.migrate
	mix download_country_database
	npm install --prefix assets
	npm install --prefix tracker
	npm run deploy --prefix tracker

server: ## Start the web server
	mix phx.server

CH_FLAGS ?= --detach -p 8123:8123 -p 9000:9000 --ulimit nofile=262144:262144 --name plausible_clickhouse

clickhouse: ## Start a container with a recent version of clickhouse
	docker run $(CH_FLAGS) --network host --volume=$$PWD/.clickhouse_db_vol:/var/lib/clickhouse clickhouse/clickhouse-server:latest-alpine

clickhouse-client: ## Connect to clickhouse
	docker exec -it plausible_clickhouse clickhouse-client -d plausible_events_db

clickhouse-prod: ## Start a container with the same version of clickhouse as the one in prod
	docker run $(CH_FLAGS) --volume=$$PWD/.clickhouse_db_vol_prod:/var/lib/clickhouse clickhouse/clickhouse-server:24.12.2.29-alpine

clickhouse-stop: ## Stop and remove the clickhouse container
	docker stop plausible_clickhouse && docker rm plausible_clickhouse

PG_FLAGS ?= --detach -e POSTGRES_PASSWORD="postgres" -p 5432:5432 --name plausible_db

postgres: ## Start a container with a recent version of postgres
	docker run $(PG_FLAGS) --volume=plausible_db:/var/lib/postgresql/data postgres:latest

postgres-client: ## Connect to postgres
	docker exec -it plausible_db psql -U postgres -d plausible_dev

postgres-prod: ## Start a container with the same version of postgres as the one in prod
	docker run $(PG_FLAGS) --volume=plausible_db_prod:/var/lib/postgresql/data postgres:15

postgres-stop: ## Stop and remove the postgres container
	docker stop plausible_db && docker rm plausible_db

browserless:
	docker run -e "TOKEN=dummy_token" -p 3000:3000 --network host ghcr.io/browserless/chromium

minio: ## Start a transient container with a recent version of minio (s3)
	docker run -d --rm -p 10000:10000 -p 10001:10001 --name plausible_minio minio/minio server /data --address ":10000" --console-address ":10001"
	while ! docker exec plausible_minio mc alias set local http://localhost:10000 minioadmin minioadmin; do sleep 1; done
	docker exec plausible_minio sh -c 'mc mb local/dev-exports && mc ilm add --expiry-days 7 local/dev-exports'
	docker exec plausible_minio sh -c 'mc mb local/dev-imports && mc ilm add --expiry-days 7 local/dev-imports'
	docker exec plausible_minio sh -c 'mc mb local/test-exports && mc ilm add --expiry-days 7 local/test-exports'
	docker exec plausible_minio sh -c 'mc mb local/test-imports && mc ilm add --expiry-days 7 local/test-imports'

minio-stop: ## Stop and remove the minio container
	docker stop plausible_minio

sso:
	$(call require, integration_id)
	@echo "Setting up local IdP service..."
	@docker run --name=idp \
  -p 8080:8080 \
  -e SIMPLESAMLPHP_SP_ENTITY_ID=http://localhost:8000/sso/$(integration_id) \
  -e SIMPLESAMLPHP_SP_ASSERTION_CONSUMER_SERVICE=http://localhost:8000/sso/saml/consume/$(integration_id) \
  -v $$PWD/extra/fixture/authsources.php:/var/www/simplesamlphp/config/authsources.php -d kenchan0130/simplesamlphp

	@sleep 2

	@echo "Use the following IdP configuration:" 
	@echo ""
	@echo "Sign-in URL: http://localhost:8080/simplesaml/saml2/idp/SSOService.php"
	@echo ""
	@echo "Entity ID: http://localhost:8080/simplesaml/saml2/idp/metadata.php"
	@echo ""
	@echo "PEM Certificate:"
	@curl http://localhost:8080/simplesaml/module.php/saml/idp/certs.php/idp.crt 2>/dev/null
	@echo ""
	@echo ""
	@echo "Following accounts are configured:"
	@echo "- user@plausible.test / plausible"
	@echo "- user1@plausible.test / plausible"
	@echo "- user2@plausible.test / plausible"
	
sso-stop:
	docker stop idp
	docker remove idp

generate-corefile:
	$(call require, integration_id)
	integration_id=$(integration_id) envsubst < $(PWD)/extra/fixture/Corefile.template > $(PWD)/extra/fixture/Corefile.gen.$(integration_id)

mock-dns: generate-corefile
	$(call require, integration_id)
	docker run --rm -p 5353:53/udp -v $(PWD)/extra/fixture/Corefile.gen.$(integration_id):/Corefile coredns/coredns:latest -conf Corefile

loadtest-server:
	@echo "Ensure your OTP installation is built with --enable-lock-counter"
	MIX_ENV=load ERL_FLAGS="-emu_type lcnt +Mdai max" iex -S mix do phx.digest + phx.server

loadtest-client:
	@echo "Set your limits for file descriptors/ephemeral ports high... Test begins shortly"
	@sleep 5
	k6 run test/load/script.js  
