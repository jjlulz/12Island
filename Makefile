TARGET := iphone:clang:14.5:12.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicIsland
DynamicIsland_FILES = Tweak.x
DynamicIsland_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
DynamicIsland_FRAMEWORKS = UIKit Contacts

include $(THEOS_MAKE_PATH)/tweak.mk
