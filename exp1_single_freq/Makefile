# ============================================================================
#  实验一 · 单频信号接收端 —— 跨平台构建（树莓派 / Jetson / 香橙派 / x86）
#  完全不依赖 MathWorks 硬件支持包，只需 gcc + libasound。
#  共享底层(音频/MAT)在 ../common，本实验专属(模型/胶水/main)在本目录。
#
#  两个独立开关：
#    MODEL = real (默认) | mock      real=编译 simulink_model/ 下的 Simulink 生成代码
#    AUDIO = alsa (默认) | null      null=合成音频(无需声卡/ALSA，仅联调)
#
#  常用组合：
#    make                      真实模型 + ALSA           ← 板上部署
#    make AUDIO=null           真实模型 + 合成音频        ← 无声卡机器上验证算法
#    make MOCK=1               桩模型 + 合成音频          ← 纯管线联调
#    make clean
#  交叉编译： make CC=aarch64-linux-gnu-gcc
# ============================================================================

CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=c11
CFLAGS  += -D_GNU_SOURCE

COMMON      := ../common
# Simulink 代码生成输出目录（重新生成后直接读取，无需拷贝）
MODEL_DIR   ?= simulink_model/single_fre_rev_ert_rtw
SHAREDUTILS := $(wildcard simulink_model/slprj/ert/_sharedutils)

CFLAGS  += -Iinclude -I$(COMMON)/include
LDLIBS  := -lm

MODEL   ?= real
AUDIO   ?= alsa
ifdef MOCK
  MODEL := mock
  AUDIO := null
endif

BUILD   := build
TARGET  := $(BUILD)/sdr_rx
SRCS    := src/main.c src/model_glue.c $(COMMON)/src/mat_sink.c

# ---- 模型来源 ----
ifeq ($(MODEL),mock)
  CFLAGS += -DUSE_MOCK_MODEL
else
  CFLAGS += -I$(MODEL_DIR) $(addprefix -I,$(SHAREDUTILS))
  SRCS   += $(wildcard $(MODEL_DIR)/*.c) $(foreach d,$(SHAREDUTILS),$(wildcard $(d)/*.c))
endif

# ---- 音频后端 ----
ifeq ($(AUDIO),null)
  CFLAGS += -DAUDIO_NULL
  SRCS   += $(COMMON)/src/audio_io_null.c
else
  SRCS   += $(COMMON)/src/audio_io.c
  LDLIBS += -lasound -lpthread -lrt
endif

# 多目录源码 -> 扁平 build/ 目标（各源文件 basename 唯一）
VPATH := src $(COMMON)/src $(MODEL_DIR) $(SHAREDUTILS)
OBJS  := $(addprefix $(BUILD)/,$(notdir $(SRCS:.c=.o)))

.PHONY: all clean
all: $(TARGET)
	@echo "==> 生成: $(TARGET)   [MODEL=$(MODEL) AUDIO=$(AUDIO)]"

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $^ -o $@ $(LDLIBS)

$(BUILD)/%.o: %.c
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD)
