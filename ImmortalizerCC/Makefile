TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ImmortalizerCC
ImmortalizerCC_BUNDLE_EXTENSION = bundle
ImmortalizerCC_FILES = ImmortalizerCC.m ImmortalizerCCMenu.m ../Localizer.m
ImmortalizerCC_CFLAGS = -fobjc-arc
ImmortalizerCC_FRAMEWORKS = UIKit 
ImmortalizerCC_PRIVATE_FRAMEWORKS = ControlCenterUIKit
ImmortalizerCC_INSTALL_PATH = /Library/ControlCenter/Bundles

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
ImmortalizerCC_LDFLAGS += -lroothide
endif

include $(THEOS_MAKE_PATH)/bundle.mk
