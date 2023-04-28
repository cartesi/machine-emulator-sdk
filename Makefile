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

FS_TOOLCHAIN_TAG     := $(TOOLCHAIN_TAG)
KERNEL_TOOLCHAIN_TAG := $(TOOLCHAIN_TAG)
ROM_TOOLCHAIN_TAG    := $(TOOLCHAIN_TAG)
TESTS_TOOLCHAIN_TAG  := $(TOOLCHAIN_TAG)

# Install settings
PREFIX= /opt/cartesi
SHARE_INSTALL_PATH= $(PREFIX)/share
IMAGES_INSTALL_PATH= $(SHARE_INSTALL_PATH)/images

INSTALL= install -p
INSTALL_EXEC= $(INSTALL) -m 0755
INSTALL_DATA= $(INSTALL) -m 0644

FS_TO_IMAGES= rootfs-v0.16.0.ext2
KERNEL_TO_IMAGES= linux-5.15.63-ctsi-2.bin
ROM_TO_IMAGES= rom-v0.16.0.bin

SRCDIRS := emulator rom tests
SRCCLEAN := $(addsuffix .clean,$(SRCDIRS))
SRCDISTC := $(addsuffix .distclean,$(SRCDIRS))

CONTAINER_BASE := /opt/cartesi/machine-emulator-sdk
CONTAINER_MAKE := /usr/bin/make

UPPER = $(shell echo '$1' | tr '[:lower:]' '[:upper:]')

all:
	@echo "Usage: make [option]\n"
	@echo "Options: emulator, rom, tests, fs, kernel or toolchain.\n"
	@echo "eg.: make emulator"

clean: $(SRCCLEAN)

distclean: $(SRCDISTC)

$(BUILDDIR) $(IMAGES_INSTALL_PATH):
	mkdir -p $@

submodules:
	git submodule update --init --recursive emulator fs kernel toolchain rom tests

emulator:
	$(MAKE) -C $@ downloads
	$(MAKE) -C $@ dep
	$(MAKE) -C $@

rom tests:
	$(MAKE) -C $@ downloads
	$(MAKE) toolchain-exec \
	    TOOLCHAIN_TAG=$($(call UPPER,$@)_TOOLCHAIN_TAG) \
	    CONTAINER_COMMAND="$(CONTAINER_MAKE) build-$@"

$(SRCCLEAN): %.clean:
	$(MAKE) -C $* clean

$(SRCDISTC): %.distclean:
	$(MAKE) -C $* distclean

build-rom:
	cd rom && \
	    make dep && \
	    make

build-tests:
	cd tests && \
	    $(MAKE) dep && \
	    $(MAKE)

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
		cartesi/toolchain:$(TOOLCHAIN_TAG) $(CONTAINER_COMMAND)

toolchain-exec:
	docker run --hostname $@ --rm \
		-e USER=$$(id -u -n) \
		-e GROUP=$$(id -g -n) \
		-e UID=$$(id -u) \
		-e GID=$$(id -g) \
		-v `pwd`:$(CONTAINER_BASE) \
		-w $(CONTAINER_BASE) \
		cartesi/toolchain:$(TOOLCHAIN_TAG) $(CONTAINER_COMMAND)

fs kernel:
	$(MAKE) -C $@ \
	    TAG=$($(call UPPER,$@)_TAG) \
	    TOOLCHAIN_TAG=$($(call UPPER,$@)_TOOLCHAIN_TAG)

toolchain:
	$(MAKE) -C $@ TOOLCHAIN_TAG=$(TOOLCHAIN_TAG)

create-symlinks:
	@ln -svf ../../rom/build/$(ROM_TO_IMAGES) emulator/src/rom.bin
	@ln -svf ../../fs/$(FS_TO_IMAGES) emulator/src/rootfs.ext2
	@ln -svf ../../kernel/$(KERNEL_TO_IMAGES) emulator/src/linux.bin

install: $(IMAGES_INSTALL_PATH)
	$(MAKE) -C emulator install
	$(MAKE) -C tests install
	cd fs && $(INSTALL_DATA) $(FS_TO_IMAGES) $(IMAGES_INSTALL_PATH)
	cd kernel && $(INSTALL_DATA) $(KERNEL_TO_IMAGES) $(IMAGES_INSTALL_PATH)
	cd rom/build && $(INSTALL_DATA) $(ROM_TO_IMAGES) $(IMAGES_INSTALL_PATH)
	cd $(IMAGES_INSTALL_PATH) && ln -s $(KERNEL_TO_IMAGES) linux.bin
	cd $(IMAGES_INSTALL_PATH) && ln -s $(ROM_TO_IMAGES) rom.bin
	cd $(IMAGES_INSTALL_PATH) && ln -s $(FS_TO_IMAGES) rootfs.ext2

.PHONY: all submodules clean fs kernel toolchain fs-env kernel-env toolchain-env $(SRCDIRS) $(SRCCLEAN)
