EDITOR=vim

install-prerequisites:
ifeq ("$(wildcard /usr/bin/docker)","")
	@echo install docker-ce, still to be tested
	sudo apt-get update
	sudo apt-get install \
    	apt-transport-https \
    	ca-certificates \
    	curl \
    	software-properties-common

	curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | sudo apt-key add -
	sudo add-apt-repository \
   		"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   		$(lsb_release -cs) \
   		stable"
   	sudo apt-get update
		sudo apt-get install -y docker-ce
endif

network: 
	@docker network create latelier 2> /dev/null; true

up: network
	docker-compose up -d

down:
	docker-compose down

restart: down up

