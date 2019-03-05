#
# Default Rules
#

.PHONY: all
all: build

#
# Building Rules
#

.PHONY: build
build:
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic-hwe/cloud-desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic-hwe/cloud-desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic-hwe/cloud-server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic-hwe/cloud-server.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic-hwe/desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic-hwe/desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic-hwe/server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic-hwe/server.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic/cloud-desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic/cloud-desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic/cloud-server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic/cloud-server.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic/desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic/desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic/server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic/generic/server.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic-hwe/cloud-desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic-hwe/cloud-desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic-hwe/cloud-server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic-hwe/cloud-server.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic-hwe/desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic-hwe/desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic-hwe/server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic-hwe/server.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic/cloud-desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic/cloud-desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic/cloud-server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic/cloud-server.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic/desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic/desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic/server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial/generic/server.sh

#
# Clean Rules
#

.PHONY: clean
clean:
	@sudo rm -fr release/*
