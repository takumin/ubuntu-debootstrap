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
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic_generic_desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic_generic_desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic_generic_server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/bionic_generic_server.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial_generic-hwe_desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial_generic-hwe_desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial_generic-hwe_server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial_generic-hwe_server.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial_generic_desktop-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial_generic_desktop.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial_generic_server-nvidia.sh
	@sudo eatmydata $(CURDIR)/overlayroot.sh $(CURDIR)/common.sh $(CURDIR)/profile/xenial_generic_server.sh

#
# Clean Rules
#

.PHONY: clean
clean:
	@rm -fr release/*