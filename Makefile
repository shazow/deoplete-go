TARGET = ./rplugin/python3/deoplete/ujson.so

CURRENT := $(shell pwd)
RPLUGIN_HOME := $(CURRENT)/rplugin/python3
RPLUGIN_PATH := $(CURRENT)/rplugin/python3/deoplete/sources/
MODULE_NAME := deoplete_go.py

GOCODE := $(shell which gocode)
GO_VERSION = $(shell go version | awk '{print $$3}' | sed -e 's/go//')
GO_STABLE_VERSION = 1.6.2
GOOS := $(shell go env GOOS)
GOARCH := $(shell go env GOARCH)

GIT := $(shell which git)
PYTHON3 := $(shell which python3)
DOCKER := $(shell which docker)
DOKCER_IMAGE := zchee/deoplete-go:${GO_STABLE_VERSION}-linux_amd64

PACKAGE ?= unsafe

ifneq ($(PACKAGE),unsafe)
	PACKAGE += unsafe
endif


all : $(TARGET)

build/:
	$(GIT) submodule update --init
	cd ./rplugin/python3/deoplete/ujson; $(PYTHON3) setup.py build --build-base=$(CURRENT)/build --build-lib=$(CURRENT)/build

rplugin/python3/deoplete/ujson.so: build/
	cp $(shell find $(CURRENT)/build -name ujson*.so) $(RPLUGIN_HOME)/deoplete/ujson.so

data/stdlib.txt:
	go tool api -contexts $(GOOS)-$(GOARCH)-cgo | sed -e s/,//g | awk '{print $$2}' | uniq > ./data/stdlib.txt
	@for pkg in $(PACKAGE) ; do \
		echo $$pkg >> ./data/stdlib.txt; \
	done
	mv ./data/stdlib.txt ./data/stdlib-$(GO_VERSION)_$(GOOS)_$(GOARCH).txt

gen_json: data/stdlib.txt
	$(GOCODE) close
	cd ./data && ./gen_json.py $(GOOS) $(GOARCH)

docker/build:
	$(DOCKER) build -t $(DOKCER_IMAGE) .

docker/gen_stdlib: docker/build
	$(DOCKER) run --rm $(DOKCER_IMAGE) cat /deoplete-go/data/stdlib-1.6.2_linux_amd64.txt > ./data/stdlib-1.6.2_linux_amd64.txt

docker/gen_json: docker/gen_stdlib
	$(DOCKER) run --rm $(DOKCER_IMAGE) > ./json_${GO_STABLE_VERSION}_linux_amd64.tar.gz
	tar xf ./json_${GO_STABLE_VERSION}_linux_amd64.tar.gz
	mv ./json_${GO_STABLE_VERSION}_linux_amd64.tar.gz ./data/json_${GO_STABLE_VERSION}_linux_amd64.tar.gz

test: lint

lint: flake8

flake8: test_modules
	@flake8 --config=$(PWD)/.flake8 ${RPLUGIN_PATH}${MODULE_NAME} || true

test_modules:
	@pip3 -q install -U -r./tests/requirements.txt

clean:
	$(RM) -rf $(CURRENT)/build $(RPLUGIN_HOME)/deoplete/ujson.so

.PHONY: test lint flake8 test_modules clean
