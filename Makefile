
.SUFFIXES:

################################################
#                                              #
#             CONSTANT DEFINITIONS             #
#                                              #
################################################

# Program constants
RGBDS   :=

RGBASM  := $(RGBDS)rgbasm
RGBLINK := $(RGBDS)rgblink
RGBFIX  := $(RGBDS)rgbfix
RGBGFX  := $(RGBDS)rgbgfx

ROM = bin/example.gb

# Argument constants
INCDIRS  = src/
WARNINGS = all extra
ASFLAGS  = -p 0xFF $(addprefix -i, $(INCDIRS)) $(addprefix -W, $(WARNINGS))
LDFLAGS  = -p 0xFF
FIXFLAGS = -p 0xFF -v

# The list of "root" ASM files that RGBASM will be invoked on
SRCS := $(shell find src -name '*.asm')

################################################
#                                              #
#                    TARGETS                   #
#                                              #
################################################

# `all` (Default target): build the ROM
all: $(ROM)
.PHONY: all

# `clean`: Clean temp and bin files
clean:
	rm -rf bin
	rm -rf obj
	rm -rf dep
	rm -rf res
.PHONY: clean

# `rebuild`: Build everything from scratch
# It's important to do these two in order if we're using more than one job
rebuild:
	$(MAKE) clean
	$(MAKE) all
.PHONY: rebuild

usage: all
	./tools/romusage bin/$(ROMNAME).map -g
.PHONY: usage

###############################################
#                                             #
#                 COMPILATION                 #
#                                             #
###############################################

# How to build a ROM
bin/%.gb bin/%.sym bin/%.map: $(patsubst src/%.asm, obj/%.o, $(SRCS))
	@mkdir -p $(@D)
	$(RGBLINK) $(LDFLAGS) -m bin/$*.map -n bin/$*.sym -o bin/$*.gb $^ \
	&& $(RGBFIX) -v $(FIXFLAGS) bin/$*.gb

# `.mk` files are auto-generated dependency lists of the "root" ASM files, to save a lot of hassle.
# Also add all obj dependencies to the dep file too, so Make knows to remake it
# Caution: some of these flags were added in RGBDS 0.4.0, using an earlier version WILL NOT WORK
# (and produce weird errors)
obj/%.o dep/%.mk: src/%.asm
	@mkdir -p $(patsubst %/, %, $(dir obj/$* dep/$*))
	$(RGBASM) $(ASFLAGS) -M dep/$*.mk -MG -MP -MQ obj/$*.o -MQ dep/$*.mk -o obj/$*.o $<

ifneq ($(MAKECMDGOALS),clean)
-include $(patsubst src/%.asm, dep/%.mk, $(SRCS))
endif

################################################
#                                              #
#                RESOURCE FILES                #
#                                              #
################################################


# By default, asset recipes convert files in `res/` into other files in `res/`
# This line causes assets not found in `res/` to be also looked for in `src/res/`
# "Source" assets can thus be safely stored there without `make clean` removing them
VPATH := src

# Convert .png files into .2bpp files.
res/%.2bpp: res/%.png
	@mkdir -p $(@D)
	$(RGBGFX) -u -o $@ $^