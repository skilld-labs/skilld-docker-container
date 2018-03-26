# List of available OS:
# - WINDOWS
# - OS_X
# - LINUX
# List of available processors
# - AMD64
# - IA32 (Intel x86)
# - ARM
ifeq ($(OS),Windows_NT)
    SYSTEM_OS = 'WINDOWS'
    ifeq ($(PROCESSOR_ARCHITEW6432),AMD64)
        SYSTEM_PROCESSOR = 'AMD64'
    else
        ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
        	SYSTEM_PROCESSOR = 'AMD64'
        endif
        ifeq ($(PROCESSOR_ARCHITECTURE),x86)
        	SYSTEM_PROCESSOR = 'IA32'
        endif
    endif
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
	    SYSTEM_OS = 'LINUX'
    endif
    ifeq ($(UNAME_S),Darwin)
	    SYSTEM_OS = 'OS_X'
    endif
    UNAME_P := $(shell uname -p)
    ifeq ($(UNAME_P),x86_64)
       	SYSTEM_PROCESSOR = 'AMD64'
    endif
    ifneq ($(filter %86,$(UNAME_P)),)
        SYSTEM_PROCESSOR = 'IA32'
    endif
    ifneq ($(filter arm%,$(UNAME_P)),)
        SYSTEM_PROCESSOR = 'ARM'
    endif
endif
