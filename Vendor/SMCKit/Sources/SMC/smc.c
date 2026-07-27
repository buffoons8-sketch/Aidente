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

#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "khashl.h"
#include "smc.h"

KHASHL_MAP_INIT(KH_LOCAL, mapKeyInfo_t, mapKeyInfo, uint32_t,
                SMCKeyData_keyInfo_t, kh_hash_uint32, kh_eq_generic)

static mapKeyInfo_t *g_keyInfoCache = NULL;
static pthread_mutex_t g_keyInfoCacheLock = PTHREAD_MUTEX_INITIALIZER;

static void ensure_cache_initialized(void) {
  if (g_keyInfoCache == NULL) {
    g_keyInfoCache = mapKeyInfo_init();
  }
}

static UInt32 FourCharCodeFromString(const UInt32Char_t *str) {
  if (str == NULL)
    return 0;
  return ((UInt32)str->chars[0] << 24) | ((UInt32)str->chars[1] << 16) |
         ((UInt32)str->chars[2] << 8) | ((UInt32)str->chars[3]);
}

static void StringFromFourCharCode(const UInt32 code, UInt32Char_t *out) {
  if (out == NULL)
    return;
  out->chars[0] = (code >> 24) & 0xFF;
  out->chars[1] = (code >> 16) & 0xFF;
  out->chars[2] = (code >> 8) & 0xFF;
  out->chars[3] = code & 0xFF;
  out->chars[4] = '\0';
}

kern_return_t SMCOpen(io_connect_t *conn) {
  if (conn == NULL) {
    return kIOReturnBadArgument;
  }

  const io_service_t service = IOServiceGetMatchingService(
      kIOMainPortDefault, IOServiceMatching("AppleSMC"));
  if (service == 0) {
    return kIOReturnNotFound;
  }

  const kern_return_t result =
      IOServiceOpen(service, mach_task_self(), 0, conn);
  IOObjectRelease(service);

  return result;
}

kern_return_t SMCClose(const io_connect_t conn) { return IOServiceClose(conn); }

static kern_return_t SMCCall(const int selector,
                             const SMCKeyData_t *inputStructure,
                             SMCKeyData_t *outputStructure,
                             const io_connect_t conn) {
  const size_t structureInputSize = sizeof(SMCKeyData_t);
  size_t structureOutputSize = sizeof(SMCKeyData_t);

  return IOConnectCallStructMethod(conn, selector, inputStructure,
                                   structureInputSize, outputStructure,
                                   &structureOutputSize);
}

SMCResult_t SMCReadKey(const UInt32Char_t *key, SMCVal_t *val,
                       const io_connect_t conn) {
  SMCResult_t result = {kIOReturnBadArgument, kSMCReturnError};

  if (key == NULL || val == NULL) {
    return result;
  }

  SMCKeyData_t inputStructure;
  SMCKeyData_t outputStructure;

  memset(&inputStructure, 0, sizeof(SMCKeyData_t));
  memset(&outputStructure, 0, sizeof(SMCKeyData_t));
  memset(val, 0, sizeof(SMCVal_t));

  const UInt32 keyCode = FourCharCodeFromString(key);
  inputStructure.key = keyCode;
  StringFromFourCharCode(keyCode, &val->key);

  result = SMCGetKeyInfo(keyCode, &outputStructure.keyInfo, conn);

  if (result.kern_res != kIOReturnSuccess ||
      result.smc_res != kSMCReturnSuccess) {
    return result;
  }

  val->dataSize = outputStructure.keyInfo.dataSize;
  StringFromFourCharCode(outputStructure.keyInfo.dataType, &val->dataType);

  inputStructure.keyInfo.dataSize = val->dataSize;
  inputStructure.data8 = SMC_CMD_READ_KEY;

  result.kern_res =
      SMCCall(SMC_KERNEL_INDEX, &inputStructure, &outputStructure, conn);
  result.smc_res = outputStructure.result;
  if (result.kern_res != kIOReturnSuccess ||
      result.smc_res != kSMCReturnSuccess) {
    return result;
  }

  memcpy(val->bytes, outputStructure.bytes, sizeof(outputStructure.bytes));
  return result;
}

SMCResult_t SMCWriteKey(const SMCVal_t *val, const io_connect_t conn) {
  SMCResult_t result = {kIOReturnBadArgument, kSMCReturnError};

  if (val == NULL) {
    return result;
  }

  SMCKeyData_keyInfo_t keyData;

  const UInt32 keyCode = FourCharCodeFromString(&val->key);
  result = SMCGetKeyInfo(keyCode, &keyData, conn);
  if (result.kern_res != kIOReturnSuccess ||
      result.smc_res != kSMCReturnSuccess) {
    return result;
  }

  if (keyData.dataSize != val->dataSize ||
      keyData.dataType != FourCharCodeFromString(&val->dataType)) {
    result.kern_res = kIOReturnBadArgument;
    result.smc_res = kSMCReturnDataTypeMismatch;
    return result;
  }

  SMCKeyData_t inputStructure;
  SMCKeyData_t outputStructure;

  memset(&inputStructure, 0, sizeof(SMCKeyData_t));
  memset(&outputStructure, 0, sizeof(SMCKeyData_t));

  inputStructure.key = keyCode;
  inputStructure.data8 = SMC_CMD_WRITE_KEY;
  inputStructure.keyInfo.dataSize = val->dataSize;
  memcpy(inputStructure.bytes, val->bytes, sizeof(val->bytes));

  result.kern_res =
      SMCCall(SMC_KERNEL_INDEX, &inputStructure, &outputStructure, conn);
  result.smc_res = outputStructure.result;

  return result;
}

SMCResult_t SMCGetKeyFromIndex(const UInt32 index, UInt32Char_t *key,
                               const io_connect_t conn) {
  SMCResult_t result = {kIOReturnBadArgument, kSMCReturnError};

  if (key == NULL) {
    return result;
  }

  SMCKeyData_t inputStructure;
  SMCKeyData_t outputStructure;

  memset(&inputStructure, 0, sizeof(SMCKeyData_t));
  memset(&outputStructure, 0, sizeof(SMCKeyData_t));

  inputStructure.data8 = SMC_CMD_GET_KEY_FROM_INDEX;
  inputStructure.data32 = index;

  result.kern_res =
      SMCCall(SMC_KERNEL_INDEX, &inputStructure, &outputStructure, conn);
  result.smc_res = outputStructure.result;
  if (result.kern_res != kIOReturnSuccess ||
      result.smc_res != kSMCReturnSuccess) {
    return result;
  }

  StringFromFourCharCode(outputStructure.key, key);

  return result;
}

SMCResult_t SMCGetKeyInfo(const UInt32 key, SMCKeyData_keyInfo_t *keyInfo,
                          const io_connect_t conn) {
  SMCResult_t result = {kIOReturnBadArgument, kSMCReturnError};

  if (keyInfo == NULL) {
    return result;
  }

  pthread_mutex_lock(&g_keyInfoCacheLock);
  ensure_cache_initialized();

  if (g_keyInfoCache == NULL) {
    pthread_mutex_unlock(&g_keyInfoCacheLock);
    result.kern_res = kIOReturnNoMemory;
    return result;
  }

  khint_t k = mapKeyInfo_get(g_keyInfoCache, key);
  if (k != kh_end(g_keyInfoCache)) {
    *keyInfo = kh_val(g_keyInfoCache, k);
    pthread_mutex_unlock(&g_keyInfoCacheLock);

    result.kern_res = kIOReturnSuccess;
    result.smc_res = kSMCReturnSuccess;
    return result;
  }

  pthread_mutex_unlock(&g_keyInfoCacheLock);

  SMCKeyData_t inputStructure;
  SMCKeyData_t outputStructure;

  memset(&inputStructure, 0, sizeof(inputStructure));
  memset(&outputStructure, 0, sizeof(outputStructure));

  inputStructure.key = key;
  inputStructure.data8 = SMC_CMD_READ_KEY_INFO;

  result.kern_res =
      SMCCall(SMC_KERNEL_INDEX, &inputStructure, &outputStructure, conn);
  result.smc_res = outputStructure.result;
  if (result.kern_res != kIOReturnSuccess ||
      result.smc_res != kSMCReturnSuccess) {
    return result;
  }

  *keyInfo = outputStructure.keyInfo;

  pthread_mutex_lock(&g_keyInfoCacheLock);

  int absent;
  k = mapKeyInfo_put(g_keyInfoCache, key, &absent);
  if (absent) {
    kh_val(g_keyInfoCache, k) = outputStructure.keyInfo;
  }

  pthread_mutex_unlock(&g_keyInfoCacheLock);

  return result;
}

void SMCCleanupCache(void) {
  pthread_mutex_lock(&g_keyInfoCacheLock);

  if (g_keyInfoCache != NULL) {
    mapKeyInfo_destroy(g_keyInfoCache);
    g_keyInfoCache = NULL;
  }

  pthread_mutex_unlock(&g_keyInfoCacheLock);
}
