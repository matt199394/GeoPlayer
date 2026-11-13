
#ifndef UTIL_H
#define UTIL_H

#include <stdint.h>

#define UTIL_GLOBAL_READ_LFN 2

// return values for utilOpenFile
#define OPEN_FILE_OK    0
#define OPEN_FILE_ERR   1
#define OPEN_FILE_WRONG 2

extern char georam;

void __fastcall__ utilAppendHex1(uint8_t n);
void __fastcall__ utilAppendHex2(uint8_t n);
void __fastcall__ utilAppendChar(char c);
void __fastcall__ utilAppendDecimal(uint16_t n);


uint8_t __fastcall__ utilOpenFile(uint8_t nDrive, const char* pStrFileName);
void utilCloseFile(void);

void utilReadSelectNormalFile(void);
int __fastcall__ utilReadNormalFile(void* buffer, unsigned int size);
uint8_t __fastcall__ utilReadByte(void);


extern int __fastcall__ (*utilRead)(void* buffer, unsigned int size);

extern const uint8_t* pFallbackDriverStart;
extern const uint8_t* pFallbackDriverEnd;

extern char utilStr[];
extern char strFileName[];


void utilReset(void);

#endif
