# Copyright 2019 Cartesi Pte. Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#

UNAME:=$(shell uname)

# Containers tags
TOOLCHAIN_TAG ?= devel
FS_TAG        ?= devel
KERNEL_TAG    ?= devel

# Install settings
PREFIX= /opt/cartesi
SHARE_INSTALL_PATH= $(PREFIX)/share

INSTALL= install -p
INSTALL_EXEC= $(INSTALL) -m 0755
INSTALL_DATA= $(INSTALL) -m 0644

FS_TO_SHARE= rootfs.ext2
KERNEL_TO_SHARE= kernel.bin
ROM_TO_SHARE= rom.bin

SRCDIRS := emulator rom tests
SRCCLEAN := $(addsuffix .clean,$(SRCDIRS))
SRCDISTC := $(addsuffix .distclean,$(SRCDIRS))

CONTAINER_BASE := /opt/cartesi/machine-emulator-sdk
CONTAINER_MAKE := /usr/bin/make

EMULATOR_INC = $(CONTAINER_BASE)/emulator/src
RISCV_CFLAGS :=-march=rv64ima -mabi=lp64

all:
	@echo "Usage: make [option]\n"
	@echo "Options: emulator, rom, tests, fs, kernel or toolchain.\n"
	@echo "eg.: make emulator"

clean: $(SRCCLEAN)

distclean: $(SRCDISTC)

$(BUILDDIR) $(SHARE_INSTALL_PATH):
	mkdir -p $@

submodules:
	git submodule update --init --recursive

emulator:
	$(MAKE) -C $@ downloads
	$(MAKE) -C $@ dep
	$(MAKE) -C $@

rom tests:
	$(MAKE) -C $@ downloads EMULATOR_INC=true
	$(MAKE) toolchain-exec CONTAINER_COMMAND="$(CONTAINER_MAKE) build-$@"

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
	    $(MAKE) EMULATOR_INC=$(EMULATOR_INC) && \
	    $(MAKE) copy-riscv-tests

run-tests:
	$(MAKE) -C emulator test TEST_PATH=`pwd`/tests/build

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

toolchain-exec:
	docker run --hostname $@ --rm \
		-e USER=$$(id -u -n) \
		-e GROUP=$$(id -g -n) \
		-e UID=$$(id -u) \
		-e GID=$$(id -g) \
		-v `pwd`:$(CONTAINER_BASE) \
		-w $(CONTAINER_BASE) \
		cartesi/image-toolchain:$(TOOLCHAIN_TAG) $(CONTAINER_COMMAND)

fs kernel toolchain:
	$(MAKE) -C $@ TAG=$($(shell echo $@ | tr a-z A-Z)_TAG) TOOLCHAIN_TAG=$(TOOLCHAIN_TAG)

install: $(SHARE_INSTALL_PATH)
	$(MAKE) -C emulator install
	$(MAKE) -C tests install
	cd fs && $(INSTALL_DATA) $(FS_TO_SHARE) $(SHARE_INSTALL_PATH)
	cd kernel && $(INSTALL_DATA) $(KERNEL_TO_SHARE) $(SHARE_INSTALL_PATH)
	cd rom/build && $(INSTALL_DATA) $(ROM_TO_SHARE) $(SHARE_INSTALL_PATH)

.PHONY: all submodules clean fs kernel toolchain fs-env kernel-env toolchain-env $(SRCDIRS) $(SRCCLEAN)
