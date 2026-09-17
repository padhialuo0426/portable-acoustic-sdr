# ============================================================================
#  实验一 · 单频信号接收端 —— 跨平台构建（树莓派 / Jetson / 香橙派 / x86）
#  完全不依赖 MathWorks 硬件支持包，只需 gcc + libasound。
#  共享底层(音频/MAT)在 ../common；本实验手写 C 在 src/，
#  Simulink 生成的算法 C 在 single_fre_rev_ert_rtw/。
#
#  两个独立开关：
#    MODEL = real (默认) | mock             real=编译 single_fre_rev_ert_rtw/ 下的 Simulink 生成代码
#    AUDIO = alsa (默认) | null | file      null=合成音频(无需声卡/ALSA)，file=raw 文件输入
#
#  常用组合：
#    make                      真实模型 + ALSA           ← 板上部署
#    make AUDIO=null           真实模型 + 合成音频        ← 无声卡机器上验证算法
#    make AUDIO=file           真实模型 + 文件输入        ← 无噪声链路验证（喂 .raw）
#    make MOCK=1               桩模型 + 合成音频          ← 纯管线联调
#    make clean
#  交叉编译： make CC=aarch64-linux-gnu-gcc
# ============================================================================

CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=c11
CFLAGS  += -D_GNU_SOURCE

COMMON      := ../common
# Simulink 代码生成输出目录（重新生成后直接读取，无需拷贝）
MODEL_DIR   ?= single_fre_rev_ert_rtw
SHAREDUTILS := $(wildcard slprj/ert/_sharedutils)

CFLAGS  += -Isrc -I$(COMMON)/include
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
else ifeq ($(AUDIO),file)
  CFLAGS += -DAUDIO_FILE
  SRCS   += $(COMMON)/src/audio_io_file.c
else
  SRCS   += $(COMMON)/src/audio_io.c
  LDLIBS += -lasound -lpthread -lrt
endif

# 多目录源码 -> 扁平 build/ 目标（各源文件 basename 唯一）
VPATH := src $(COMMON)/src $(MODEL_DIR) $(SHAREDUTILS)
OBJS  := $(addprefix $(BUILD)/,$(notdir $(SRCS:.c=.o)))
CONFIG := $(BUILD)/.config

# 配置改变时更新签名；配置未变则保留时间戳，普通 make 无需重编。
# SRCS 也参与签名，避免切回旧后端或删除生成源码后漏掉重新链接。

.PHONY: all clean FORCE
all: $(TARGET)
	@echo "==> 生成: $(TARGET)   [MODEL=$(MODEL) AUDIO=$(AUDIO)]"

$(TARGET): $(OBJS) $(CONFIG)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@ $(LDLIBS)

FORCE:

$(CONFIG): FORCE
	@mkdir -p $(BUILD)
	@printf '%s\n' '$(MODEL)' '$(AUDIO)' '$(MODEL_DIR)' '$(CC)' '$(CPPFLAGS)' '$(CFLAGS)' '$(LDFLAGS)' '$(LDLIBS)' '$(SRCS)' > $@.tmp
	@cmp -s $@.tmp $@ && rm -f $@.tmp || mv -f $@.tmp $@

$(BUILD)/%.o: %.c $(CONFIG)
	@mkdir -p $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

clean:
	rm -rf $(BUILD)

-include $(OBJS:.o=.d)
