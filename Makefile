.PHONY: install server clickhouse clickhouse-arm clickhouse-stop postgres postgres-stop

install:
	mix deps.get
	mix ecto.create
	mix ecto.migrate
	mix download_country_database
	npm install --prefix assets

server:
	mix phx.server

clickhouse:
	docker run --detach -p 8123:8123 --ulimit nofile=262144:262144 --volume=$$PWD/.clickhouse_db_vol:/var/lib/clickhouse --name plausible_clickhouse clickhouse/clickhouse-server:21.11.3.6

clickhouse-arm:
	docker run --detach -p 8123:8123 --ulimit nofile=262144:262144 --volume=$$PWD/.clickhouse_db_vol:/var/lib/clickhouse --name plausible_clickhouse altinity/clickhouse-server:21.12.3.32.altinitydev.arm

clickhouse-stop:
	docker stop plausible_clickhouse && docker rm plausible_clickhouse

postgres:
	docker run --detach -e POSTGRES_PASSWORD="postgres" -p 5432:5432 --volume=plausible_db:/var/lib/postgresql/data --name plausible_db postgres:12

postgres-stop:
	docker stop plausible_db && docker rm plausible_db
