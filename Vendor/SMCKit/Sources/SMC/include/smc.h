/*
 MIT License

 Copyright (c) 2025 Sriman Achanta

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
*/

#ifndef SMC_H
#define SMC_H

#include <IOKit/IOKitLib.h>

#define SMC_KERNEL_INDEX 2

#define SMC_CMD_READ_KEY 5           // Read value at key
#define SMC_CMD_WRITE_KEY 6          // Write value at Key
#define SMC_CMD_GET_KEY_FROM_INDEX 8 // Get key at SMC table index
#define SMC_CMD_READ_KEY_INFO 9
#define SMC_CMD_READ_POWER_LIMIT 11
#define SMC_CMD_READ_VERSION 12

typedef UInt8 smc_return_t;

#define kSMCReturnSuccess 0
#define kSMCReturnError 1
#define kSMCReturnKeyNotFound 132
#define kSMCReturnDataTypeMismatch 140

typedef struct {
  unsigned char major;
  unsigned char minor;
  unsigned char build;
  unsigned char reserved[1];
  UInt16 release;
} SMCKeyData_vers_t;

typedef struct {
  UInt16 version;
  UInt16 length;
  UInt32 cpuPLimit;
  UInt32 gpuPLimit;
  UInt32 memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
  UInt32 dataSize;
  UInt32 dataType;
  UInt8 dataAttributes;
} SMCKeyData_keyInfo_t;

typedef unsigned char SMCBytes_t[32];

typedef struct {
  UInt32 key;
  SMCKeyData_vers_t vers;
  SMCKeyData_pLimitData_t pLimitData;
  SMCKeyData_keyInfo_t keyInfo;
  UInt8 result;
  UInt8 status;
  UInt8 data8;   // CMD Selector
  UInt32 data32; // CMD Context
  SMCBytes_t bytes;
} SMCKeyData_t;

typedef struct {
  unsigned char chars[5];
} UInt32Char_t;

typedef struct {
  UInt32Char_t key;
  UInt32 dataSize;
  UInt32Char_t dataType;
  SMCBytes_t bytes;
} SMCVal_t;

typedef struct {
  kern_return_t kern_res;
  smc_return_t smc_res;
} SMCResult_t;

kern_return_t SMCOpen(io_connect_t *conn);
kern_return_t SMCClose(const io_connect_t conn);

SMCResult_t SMCReadKey(const UInt32Char_t *key, SMCVal_t *val,
                       const io_connect_t conn);
SMCResult_t SMCWriteKey(const SMCVal_t *val, const io_connect_t conn);
SMCResult_t SMCGetKeyFromIndex(const UInt32 index, UInt32Char_t *key,
                               const io_connect_t conn);
SMCResult_t SMCGetKeyInfo(const UInt32 key, SMCKeyData_keyInfo_t *keyInfo,
                          const io_connect_t conn);

void SMCCleanupCache(void);

#endif
