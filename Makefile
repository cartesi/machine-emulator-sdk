UNAME:=$(shell uname)

SRCDIRS := emulator rom tests
SRCCLEAN := $(addsuffix .clean,$(SRCDIRS))
SRCDISTC := $(addsuffix .distclean,$(SRCDIRS))

CONTAINER_BASE := /opt/cartesi/machine-emulator-sdk
CONTAINER_MAKE := /usr/bin/make

EMULATOR_INC = $(CONTAINER_BASE)/emulator/src
RISCV_CFLAGS :=-march=rv64ima -mabi=lp64

all: submodules $(SRCDIRS)

clean: $(SRCCLEAN)

distclean: $(SRCDISTC)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

submodules:
	git submodule update --init --recursive

emulator:
	$(MAKE) -C $@ dep
	$(MAKE) -C $@

rom tests:
	$(MAKE) -C $@ downloads EMULATOR_INC=true
	$(MAKE) CONTAINER_COMMAND="$(CONTAINER_MAKE) build-$@" toolchain-env

$(SRCCLEAN): %.clean:
	$(MAKE) -C $* clean

$(SRCDISTC): %.distclean:
	$(MAKE) -C $* distclean

build-rom:
	cd rom && \
	    export CFLAGS="$(RISCV_CFLAGS)" && \
	    make dep EMULATOR_INC=$(EMULATOR_INC) && \
	    make EMULATOR_INC=$(EMULATOR_INC)

build-tests:
	cd tests && \
	    $(MAKE) dep EMULATOR_INC=$(EMULATOR_INC) && \
	    $(MAKE) EMULATOR_INC=$(EMULATOR_INC)

toolchain-env:
	@docker run --hostname toolchain-env -it --rm \
		-e USER=$$(id -u -n) \
		-e GROUP=$$(id -g -n) \
		-e UID=$$(id -u) \
		-e GID=$$(id -g) \
		-v `pwd`:$(CONTAINER_BASE) \
		-w $(CONTAINER_BASE) cartesi/toolchain-env:v1 $(CONTAINER_COMMAND)

build-toolchain-env:
	docker build -t cartesi/toolchain-env:v1 tools/toolchain-env


.PHONY: all submodules clean $(SRCDIRS) $(SRCCLEAN)
