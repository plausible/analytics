install:
	mix deps.get
	mix ecto.create
	mix ecto.migrate
	npm install --prefix assets

server:
	mix phx.server

clickhouse:
	docker run --detach -p 8123:8123 --ulimit nofile=262144:262144 --volume=$$PWD/.clickhouse_db_vol:/var/lib/clickhouse --name plausible_clickhouse yandex/clickhouse-server:21.3.2.5

clickhouse-stop:
	docker stop plausible_clickhouse && docker rm plausible_clickhouse

postgres:
	docker run --detach -e POSTGRES_PASSWORD="postgres" -p 5432:5432 --volume=plausible_db:/var/lib/postgresql/data --name plausible_db postgres:12

postgres-stop:
	docker stop plausible_db && docker rm plausible_db

dummy_event:
	curl 'http://localhost:8000/api/event' \
		-H 'authority: localhost:8000' \
		-H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36 OPR/71.0.3770.284' \
		-H 'content-type: text/plain' \
		-H 'accept: */*' \
		-H 'origin: http://dummy.site' \
		-H 'sec-fetch-site: cross-site' \
		-H 'sec-fetch-mode: cors' \
		-H 'sec-fetch-dest: empty' \
		-H 'referer: http://dummy.site' \
		-H 'accept-language: en-US,en;q=0.9' \
		--data-binary '{"n":"pageview","u":"http://dummy.site","d":"dummy.site","r":null,"w":1666}' \
		--compressed
