# 实验五 · SSTV 接收机；MODEL=real|mock，AUDIO=alsa|file|null。
CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=c11
CFLAGS  += -D_GNU_SOURCE

COMMON      := ../common
MODEL_DIR   ?= sstv_receive_ert_rtw
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
TARGET  := $(BUILD)/sstv_rx
SRCS    := src/main.c src/model_glue.c $(COMMON)/src/mat_sink.c

ifeq ($(MODEL),mock)
  CFLAGS += -DUSE_MOCK_MODEL
else
  CFLAGS += -I$(MODEL_DIR) $(addprefix -I,$(SHAREDUTILS))
  SRCS   += $(wildcard $(MODEL_DIR)/*.c) $(foreach d,$(SHAREDUTILS),$(wildcard $(d)/*.c))
endif

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
