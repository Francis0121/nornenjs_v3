# This file is generated by gyp; do not edit.

TOOLSET := target
TARGET := cuda
DEFS_Debug := \
	'-D_LARGEFILE_SOURCE' \
	'-D_FILE_OFFSET_BITS=64' \
	'-DBUILDING_NODE_EXTENSION' \
	'-DDEBUG' \
	'-D_DEBUG'

# Flags passed to all source files.
CFLAGS_Debug := \
	-Wall \
	-Wextra \
	-Wno-unused-parameter \
	-pthread \
	-m32 \
	-g \
	-O0

# Flags passed to only C files.
CFLAGS_C_Debug :=

# Flags passed to only C++ files.
CFLAGS_CC_Debug := \
	-fno-rtti \
	-fno-exceptions

INCS_Debug := \
	-I/home/russa/.node-gyp/0.10.35/src \
	-I/home/russa/.node-gyp/0.10.35/deps/uv/include \
	-I/home/russa/.node-gyp/0.10.35/deps/v8/include \
	-I/usr/local/include \
	-I/usr/local/cuda-6.0/include \
	-I/usr/local/cuda/include

DEFS_Release := \
	'-D_LARGEFILE_SOURCE' \
	'-D_FILE_OFFSET_BITS=64' \
	'-DBUILDING_NODE_EXTENSION'

# Flags passed to all source files.
CFLAGS_Release := \
	-Wall \
	-Wextra \
	-Wno-unused-parameter \
	-pthread \
	-m32 \
	-O2 \
	-fno-strict-aliasing \
	-fno-tree-vrp \
	-fno-omit-frame-pointer

# Flags passed to only C files.
CFLAGS_C_Release :=

# Flags passed to only C++ files.
CFLAGS_CC_Release := \
	-fno-rtti \
	-fno-exceptions

INCS_Release := \
	-I/home/russa/.node-gyp/0.10.35/src \
	-I/home/russa/.node-gyp/0.10.35/deps/uv/include \
	-I/home/russa/.node-gyp/0.10.35/deps/v8/include \
	-I/usr/local/include \
	-I/usr/local/cuda-6.0/include \
	-I/usr/local/cuda/include

OBJS := \
	$(obj).target/$(TARGET)/src/bindings.o \
	$(obj).target/$(TARGET)/src/ctx.o \
	$(obj).target/$(TARGET)/src/device.o \
	$(obj).target/$(TARGET)/src/function.o \
	$(obj).target/$(TARGET)/src/mem.o \
	$(obj).target/$(TARGET)/src/module.o

# Add to the list of files we specially track dependencies for.
all_deps += $(OBJS)

# CFLAGS et al overrides must be target-local.
# See "Target-specific Variable Values" in the GNU Make manual.
$(OBJS): TOOLSET := $(TOOLSET)
$(OBJS): GYP_CFLAGS := $(DEFS_$(BUILDTYPE)) $(INCS_$(BUILDTYPE))  $(CFLAGS_$(BUILDTYPE)) $(CFLAGS_C_$(BUILDTYPE))
$(OBJS): GYP_CXXFLAGS := $(DEFS_$(BUILDTYPE)) $(INCS_$(BUILDTYPE))  $(CFLAGS_$(BUILDTYPE)) $(CFLAGS_CC_$(BUILDTYPE))

# Suffix rules, putting all outputs into $(obj).

$(obj).$(TOOLSET)/$(TARGET)/%.o: $(srcdir)/%.cpp FORCE_DO_CMD
	@$(call do_cmd,cxx,1)

# Try building from generated source, too.

$(obj).$(TOOLSET)/$(TARGET)/%.o: $(obj).$(TOOLSET)/%.cpp FORCE_DO_CMD
	@$(call do_cmd,cxx,1)

$(obj).$(TOOLSET)/$(TARGET)/%.o: $(obj)/%.cpp FORCE_DO_CMD
	@$(call do_cmd,cxx,1)

# End of this set of suffix rules
### Rules for final target.
LDFLAGS_Debug := \
	-pthread \
	-rdynamic \
	-m32 \
	-L/usr/local/lib

LDFLAGS_Release := \
	-pthread \
	-rdynamic \
	-m32 \
	-L/usr/local/lib

LIBS := \
	-lcuda

$(obj).target/cuda.node: GYP_LDFLAGS := $(LDFLAGS_$(BUILDTYPE))
$(obj).target/cuda.node: LIBS := $(LIBS)
$(obj).target/cuda.node: TOOLSET := $(TOOLSET)
$(obj).target/cuda.node: $(OBJS) FORCE_DO_CMD
	$(call do_cmd,solink_module)

all_deps += $(obj).target/cuda.node
# Add target alias
.PHONY: cuda
cuda: $(builddir)/cuda.node

# Copy this to the executable output path.
$(builddir)/cuda.node: TOOLSET := $(TOOLSET)
$(builddir)/cuda.node: $(obj).target/cuda.node FORCE_DO_CMD
	$(call do_cmd,copy)

all_deps += $(builddir)/cuda.node
# Short alias for building this executable.
.PHONY: cuda.node
cuda.node: $(obj).target/cuda.node $(builddir)/cuda.node

# Add executable to "all" target.
.PHONY: all
all: $(builddir)/cuda.node

