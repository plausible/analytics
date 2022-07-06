.PHONY: install server clickhouse clickhouse-arm clickhouse-stop postgres postgres-stop dummy_event

install:
	mix deps.get
	mix ecto.create
	mix ecto.migrate
	mix download_country_database
	npm install --prefix assets

server:
	mix phx.server

clickhouse:
	docker run --detach -p 8123:8123 --ulimit nofile=262144:262144 --volume=$$PWD/.clickhouse_db_vol:/var/lib/clickhouse --name plausible_clickhouse yandex/clickhouse-server:21.3.2.5

clickhouse-arm:
	docker run --detach -p 8123:8123 --ulimit nofile=262144:262144 --volume=$$PWD/.clickhouse_db_vol:/var/lib/clickhouse --name plausible_clickhouse altinity/clickhouse-server:21.12.3.32.altinitydev.arm

clickhouse-stop:
	docker stop plausible_clickhouse && docker rm plausible_clickhouse

postgres:
	docker run --detach -e POSTGRES_PASSWORD="postgres" -p 5432:5432 --volume=plausible_db:/var/lib/postgresql/data --name plausible_db postgres:12

postgres-stop:
	docker stop plausible_db && docker rm plausible_db

dummy_event:
	curl 'http://localhost:8000/api/event' \
		-H 'X-Forwarded-For: 127.0.0.1' \
		-H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36 OPR/71.0.3770.284' \
		-H 'Content-Type: text/plain' \
		--data-binary '{"n":"pageview","u":"http://dummy.site/some-page","d":"dummy.site","r":null,"w":1666}' \
		--compressed
