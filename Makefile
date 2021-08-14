TARGET = iphone:clang:latest:11.0
ARCHS = arm64
PACKAGE_VERSION = 1.0.0
DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YouMusicPiP
$(TWEAK_NAME)_FILES = Tweak.x LegacyPiPCompat.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_FRAMEWORKS = AVKit

include $(THEOS_MAKE_PATH)/tweak.mk
