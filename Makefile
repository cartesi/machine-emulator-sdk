# Copyright Cartesi and individual authors (see AUTHORS)
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

UNAME:=$(shell uname)

# Containers tags
TOOLCHAIN_TAG ?= devel
KERNEL_TAG    ?= devel

KERNEL_TOOLCHAIN_TAG := $(TOOLCHAIN_TAG)

# Install settings
PREFIX?= /usr
SHARE_INSTALL_PATH= $(PREFIX)/share/cartesi-machine
IMAGES_INSTALL_PATH= $(SHARE_INSTALL_PATH)/images

INSTALL= install -p
INSTALL_EXEC= $(INSTALL) -m 0755
INSTALL_DATA= $(INSTALL) -m 0644

TOOLS_TO_IMAGES= rootfs-tools-v0.14.1.ext2
KERNEL_TO_IMAGES= linux-6.5.13-ctsi-1-v0.20.0.bin

SRCDIRS := emulator
SRCCLEAN := $(addsuffix .clean,$(SRCDIRS))
SRCDISTC := $(addsuffix .distclean,$(SRCDIRS))

CONTAINER_BASE := /opt/cartesi/machine-emulator-sdk
CONTAINER_MAKE := /usr/bin/make

UPPER = $(shell echo '$1' | tr '[:lower:]' '[:upper:]')

export PREFIX

all:
	@echo "Usage: make [option]\n"
	@echo "Options: toolchain, kernel, tools, emulator and solidity-step.\n"
	@echo "eg.: make emulator"

clean: $(SRCCLEAN)

distclean: $(SRCDISTC)

$(BUILDDIR) $(IMAGES_INSTALL_PATH):
	mkdir -p $@

submodules:
	git submodule update --init --recursive emulator kernel toolchain solidity-step tools

emulator:
	$(MAKE) -C $@

$(SRCCLEAN): %.clean:
	$(MAKE) -C $* clean

$(SRCDISTC): %.distclean:
	$(MAKE) -C $* distclean

run-tests:
	$(MAKE) -C emulator build-tests-all
	$(MAKE) -C emulator test

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

kernel:
	$(MAKE) -C $@ \
	    TAG=$($(call UPPER,$@)_TAG) \
	    TOOLCHAIN_TAG=$($(call UPPER,$@)_TOOLCHAIN_TAG)

tools:
	$(MAKE) -C $@

toolchain:
	$(MAKE) -C $@ TOOLCHAIN_TAG=$(TOOLCHAIN_TAG)

solidity-step:
	$(MAKE) -C $@ build

create-symlinks:
	@ln -svf ../../tools/$(TOOLS_TO_IMAGES) emulator/src/rootfs.ext2
	@ln -svf ../../kernel/artifacts/$(KERNEL_TO_IMAGES) emulator/src/linux.bin

install: $(IMAGES_INSTALL_PATH)
	$(MAKE) -C emulator install
	cd kernel/artifacts && $(INSTALL_DATA) $(KERNEL_TO_IMAGES) $(IMAGES_INSTALL_PATH)
	cd tools && $(INSTALL_DATA) $(TOOLS_TO_IMAGES) $(IMAGES_INSTALL_PATH)
	cd $(IMAGES_INSTALL_PATH) && ln -s $(KERNEL_TO_IMAGES) linux.bin
	cd $(IMAGES_INSTALL_PATH) && ln -s $(TOOLS_TO_IMAGES) rootfs.ext2

.PHONY: all submodules clean kernel toolchain tools solidity-step kernel-env toolchain-env $(SRCDIRS) $(SRCCLEAN)
