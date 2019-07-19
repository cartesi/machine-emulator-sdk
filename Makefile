UNAME:=$(shell uname)

# Containers tags
TOOLCHAIN_TAG ?= devel
FS_TAG        ?= devel
KERNEL_TAG    ?= devel

SRCDIRS := emulator rom tests
SRCCLEAN := $(addsuffix .clean,$(SRCDIRS))
SRCDISTC := $(addsuffix .distclean,$(SRCDIRS))

CONTAINER_BASE := /opt/cartesi/machine-emulator-sdk
CONTAINER_MAKE := /usr/bin/make

EMULATOR_INC = $(CONTAINER_BASE)/emulator/src
RISCV_CFLAGS :=-march=rv64ima -mabi=lp64

all: $(SRCDIRS)

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
	$(MAKE) toolchain-env CONTAINER_COMMAND="$(CONTAINER_MAKE) build-$@"

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

fs-env:
	@docker run --hostname $@ -it --rm \
		-v `pwd`:$(CONTAINER_BASE) \
		-w $(CONTAINER_BASE) \
		cartesi/image-rootfs:$(FS_TAG) $(CONTAINER_COMMAND)

kernel-env:
	@docker run --hostname $@ -it --rm \
		-v `pwd`:$(CONTAINER_BASE) \
		-w $(CONTAINER_BASE) \
		cartesi/image-kernel:$(KERNEL_TAG) $(CONTAINER_COMMAND)

toolchain-env:
	docker run --hostname $@ -it --rm \
		-e USER=$$(id -u -n) \
		-e GROUP=$$(id -g -n) \
		-e UID=$$(id -u) \
		-e GID=$$(id -g) \
		-v `pwd`:$(CONTAINER_BASE) \
		-w $(CONTAINER_BASE) \
		cartesi/image-toolchain:$(TOOLCHAIN_TAG) $(CONTAINER_COMMAND)

fs kernel toolchain:
	$(MAKE) -C $@ TAG=$($(shell echo $@ | tr a-z A-Z)_TAG) TOOLCHAIN_TAG=$(TOOLCHAIN_TAG)


.PHONY: all submodules clean fs kernel toolchain fs-env kernel-env toolchain-env $(SRCDIRS) $(SRCCLEAN)
