TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ImmortalizerPrefs

ImmortalizerPrefs_FILES = IPBRootListController.m ../Localizer.m
ImmortalizerPrefs_FRAMEWORKS = UIKit
ImmortalizerPrefs_PRIVATE_FRAMEWORKS = Preferences
ImmortalizerPrefs_INSTALL_PATH = /Library/PreferenceBundles
ImmortalizerPrefs_CFLAGS = -fobjc-arc
ImmortalizerPrefs_EXTRA_FRAMEWORKS = AltList

# Version shown in the settings header, taken from control
IPB_VERSION := $(shell sed -n 's/^Version: //p' $(THEOS_PROJECT_DIR)/control)
ifeq ($(IPB_VERSION),)
$(error no Version line in $(THEOS_PROJECT_DIR)/control)
endif
ImmortalizerPrefs_CFLAGS += -DPACKAGE_VERSION='"$(IPB_VERSION)"'

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
ImmortalizerPrefs_LDFLAGS += -lroothide
endif

include $(THEOS_MAKE_PATH)/bundle.mk
