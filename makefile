start:
	docker compose up -d

restart:
	docker compose down
	-docker rmi test
	docker compose up -d
	docker compose logs -f

stop:
	docker compose down
	-docker rmi test

logs:
	docker compose logs -f

exec:
	docker exec -it test /bin/bash

ping:
	curl -X GET http://192.168.50.30:5572