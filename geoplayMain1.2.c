//cl65 -v -t c64 -T -O -I include -C geoplay.cfg geoplayMain1.c screen.c FileDlg.c utility.c Dir.c geoplay-asm1.s -o GeoPlayerH.prg
//run: sys 16384
//Launch with SYS 57000 or SYS 57E3 once image is in neoram.
//exomizer sfx 0x4000 GeoPlayerH.prg -o GeoPlayerHF.prg -n

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <conio.h>
#include <stdlib.h>
#include <cbm.h>
#include <peekpoke.h>

#include "geoplay.h"
#include "util.h"


#define koalaBmp ((unsigned char *)0x2000)
#define tuneAddr ((unsigned char *)0x1000)
#define SID_MAX_SIZE 0x1000                       // SID area: $1000-$1fff
#define RamPage ((unsigned char *)0xde00)
#define BankLo  (*(unsigned char *)0xdffe)
#define BankHi  (*(unsigned char *)0xdfff)

#define MAX_PICS 10                               // GeoRAM blocks used by the slide show

// set by the asm part when the Koala bitmap has overwritten $2000-$3fff
// (ReadMe, SuperMon+ and the logo are gone until the program is restarted)
extern unsigned char koalaFlag;

// ---- forward declarations of the functions that are not in geoplay.h
static void doInfo(void);
static void doSupermon(void);
static void showWelcome(void);
static void redrawMain(void);


unsigned char downloader[171] = {
	0xA2, 0x00, 0xBD, 0x10, 0xDE, 0x9D, 0x00, 0xC0, 0xE8, 0xE0, 0x36, 0xD0,
	0xF5, 0x4C, 0x00, 0xC0, 0xA9, 0x01, 0x8D, 0xFE, 0xDF, 0xA9, 0x00, 0x8D,
	0xFF, 0xDF, 0xAD, 0x00, 0xDE, 0x8D, 0x1E, 0xC0, 0xAD, 0x01, 0xDE, 0x8D,
	0x1F, 0xC0, 0xA2, 0x02, 0xA0, 0x01, 0xBD, 0x00, 0xDE, 0x8D, 0x01, 0x08,
	0xEE, 0x1E, 0xC0, 0xD0, 0x03, 0xEE, 0x1F, 0xC0, 0xE8, 0xD0, 0xEF, 0xC8,
	0x8C, 0xFE, 0xDF, 0xC0, 0xA8, 0xD0, 0xE7, 0x20, 0x74, 0xA4, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x4C, 0x00, 0xDE
};


unsigned char str [8];
unsigned char buffer2[2];
static char metadata[44];
static char SIDmetadata[0x7e];
uint16_t size;
uint8_t waveOK;
static uint8_t koalaCounter;
static uint8_t sidValid = 1;      // the tune at $1000 is playable (the built-in one at start)
static uint8_t geoFull;           // set by uploadPages() when the GeoRAM is full

static const uint16_t sampleRates[4] = {8000, 11025, 16000, 22050};

static  const char stringRIFF[] = {0x52, 0x49, 0x46, 0x46};  //"RIFF"
static  const char stringWAVE[] = {0x57, 0x41, 0x56, 0x45};  //"WAVE"
static  const char stringFMT[]  = {0x66, 0x6D, 0x74, 0x20};  //"fmt "
static  const char stringDATA[] = {0x64, 0x61, 0x74, 0x61};  //"data"
static  const char stringPSID[] = {0x50, 0x53, 0x49, 0x44};  //"PSID"


static  const char* keyControls[]=
{       
          "Space  -> Pause/Resume",
          "F1/F7  -> Back 5/Forward 10sec",
          "<-     -> Rewind",
          "S      -> Stop",
          "+/-    -> Screen On/Off",
          "R      -> Repeat On/Off",
          "F2     -> Main Menu",
          "                 ",
          "                 ",
          "                 ",
          "                 ",
          "                 ",
          "                 ",
          "                 ",
          "                 ",
          NULL
};

static  const char* selectOutput[]=
{       
          "S -->SID",
          "D -->DigiMax",
          NULL
};

static const char* apStrFileOpenError[] =
{
        "Cannot open this file.",
        NULL
};

static const char* apStrUploadComplete[] =
{
        "Congratulations!",
        "Upload completed.",
        NULL
};

static const char* apStrLoadingComplete[] =
{
        "Congratulations!",
        "Loading completed.",
        NULL
};

static const char* apStrWaveNotSupported[] =
{
        "WAVE Not Supported",
		"------------------",
		"Must be:PCM-Mono 8 or 16 Bit",
		"SampleRate(Hz):8000/11025/16000/22050",
        NULL
};

static const char* apStrNoWave[] =
{
        "No WAVE in GeoRAM!",
        "Use Wave -> Upload Wave",
        NULL
};

static const char* apStrBadFmt[] =
{
        "Damaged WAVE file!",
        "(no fmt/data chunk)",
        NULL
};

static const char* apStrSIDNotPSID[] =
{
        "Not PSID file!",
        NULL
};

static const char* apStrSIDTooBig[] =
{
        "SID larger than 4KB!",
        "Not loaded.",
        NULL
};

static const char* apStrNoSID[] =
{
        "No valid SID loaded!",
        "Use SID -> Load SID",
        NULL
};

static const char* apStrNotKoala[] =
{
        "Not Koala file!",
        NULL
};

static const char* apStrMaxPics[] =
{
        "Max 10 images in",
        "the slide show.",
        NULL
};

static const char* apStrKoalaRam[] =
{
        "Overwritten by Koala!",
        "Restart the program.",
        NULL
};

static const char* apStrBadSIDaddr[] =
{
        "Init Addr Not at 0x1000",
		"Play Addr Not at 0x1003",
        NULL
};

static const char* apStrUploadedPRG[] =
{
        "PRG Uploaded in Georam!",
		"1. reset computer",
		"2. SYS 57000 or 57E3",
		"3. RUN",
        NULL
};

static const char* apStrGeoramNotPresent[] =
{
        "GeoRaM Not Present!",
        NULL
};

static const char* apStrGeoramFull[] =
{
        "GeoRAM is full!",
        "File truncated.",
        NULL
};

// ---------------------------------------------------------------- menus

ScreenMenuEntry aHelpMenuEntries[] =
{
		{ "ReadMe", doInfo, returnTrue },
        { "About", showAbout, returnTrue },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aMainMenuEntries[] =
{       
        { "PRG Uploader", uploadPRG, returnTrue },
		{ "Bin uploader", uploadImage, returnTrue },
		{ "SuperMon+", doSupermon, returnTrue },
        { "Reset", utilReset, returnTrue },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aPlayMenuEntries[] =
{
        { "Play Wave", playWave, returnTrue },
		{ "Upload Wave", uploadWave, returnTrue },
		{ "DigiMax/SID output", digiOutput, returnTrue },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aPlaySIDEntries[] =
{
        { "Play SID", playSID, returnTrue },
		{ "Stop SID", stopSID, returnTrue },
		{ "Load SID", loadSID, returnTrue },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aKoalaMenuEntries[] =
{
		{ "Upoad To GeoRam", uploadKoala, returnTrue },
		{ "Load To C64Ram", loadKoala, returnTrue },
        { "Show Koala Image", showKoalaImage, returnTrue },
		{ "Geo Slide Show", slideShow, returnTrue },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aTextMenuEntries[] =
{
        { "LoadTextFile ", loadText, returnTrue },
        { NULL, NULL, 0 }
};

// ---------------------------------------------------------------- helpers

// status line, safe for any length (strStatus holds 40 characters + 0)
static void showStatus(const char* s)
{
    strncpy(strStatus, s, 40);
    strStatus[40] = 0;
    refreshStatusLine();
}

static void statusFromUtil(void)
{
    showStatus(utilStr);
}

static void __fastcall__ execMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries)
{
    screenDoMenu(x, y, pMenuEntries);
    cursor(0);
}

// File dialog + open. Returns 0 if cancelled. The directory window leaves
// the (blinking) cursor on, so it is switched off again here.
static uint8_t selectFile(void)
{
    uint8_t rv;

    do
    {
        refreshMainScreen();            // cancella il box del menu a tendina
        rv = fileDlg(strFileName, "a");
        cursor(0);
        if (!rv)
            return 0;

        rv = utilOpenFile(fileDlgGetDriveNumber(), strFileName);
        if (rv == 1)
            screenPrintSimpleDialog(apStrFileOpenError);
    }
    while (rv != OPEN_FILE_OK);

    refreshMainScreen();
    return 1;
}

static void checkGeoram(void)
{
    static const char* const geoNames[5] =
    {
        "GeoRAM:512Kb", "GeoRAM:1Mb", "GeoRAM:2Mb", "GeoRAM:4Mb",
        "GeoRAM Not Found"
    };

    utilGeoram();        // sets georam (1..4, 5 = none), maxmem and the metadata page
    if (georam >= 1 && georam <= 5)
        strcat(utilStr, geoNames[georam - 1]);
}

// usable 256 byte pages of the GeoRAM (the last page holds the wave metadata)
static uint16_t maxPages(void)
{
    return (uint16_t)(1024u << georam) - 1;
}

static uint8_t noGeoram(void)
{
    if (georam == 5)
    {
        screenPrintSimpleDialog(apStrGeoramNotPresent);
        return 1;
    }
    return 0;
}

// Read the open file into the GeoRAM, 256 bytes per page.
// block 0xff: linear (the block follows the page number), otherwise the
// whole file goes into that fixed 16K block. pic: picture number shown in
// the status line (0 = none). Returns the page after the last one written.
static uint16_t uploadPages(uint16_t nPage, uint8_t block, uint8_t pic)
{
    uint16_t limit = (block == 0xff) ? maxPages() : 64;
    uint16_t nBytes;

    geoFull = 0;
    for (;;)
    {
        if (nPage >= limit)
        {
            geoFull = 1;
            break;
        }
        BankLo = (nPage & 0x3f);
        BankHi = (block == 0xff) ? (uint8_t)(nPage >> 6) : block;

        nBytes = utilRead(RamPage, 0x100);
        if (!nBytes)
            break;

        ++nPage;
        if (!(nPage & 3))                  // every KB: the status line is slow
        {
            strcpy(utilStr, "Uploading:");
            strcat(utilStr, strFileName);
            strcat(utilStr, " Page ");
            utilAppendDecimal(nPage);
            if (pic)
            {
                strcat(utilStr, " Pic n:");
                utilAppendDecimal(pic);
            }
            statusFromUtil();
        }
    }
    BankLo = 0;
    BankHi = 0;
    return nPage;
}

// ---------------------------------------------------------------- output

static void digiOutput(void)
{
    screenPrintDialog2(selectOutput);

    sidDigimax = screenGetKey();

    if (sidDigimax)
        showStatus("Output: DigiMAx");
    else
        showStatus("Output: SID");
}

// ---------------------------------------------------------------- wave

void printMetadata(void)
{
    strcpy(utilStr, "");
    if (metadata[0] == 1)
        strcpy(utilStr, "PCM ");
    else if (metadata[0] == 6)
        strcpy(utilStr, "A-law ");
    else if (metadata[0] == 7)
        strcpy(utilStr, "Mu-law ");

    if (metadata[2] == 1)
        strcat(utilStr, "Mono ");
    else if (metadata[2] == 2)
        strcat(utilStr, "Stereo ");

    size = ((uint8_t)metadata[4] | ((uint8_t)metadata[5] << 8));
    utoa(size, (char*)str, 10);
    strcat(utilStr, "Rate:");
    strcat(utilStr, (char*)str);
    strcat(utilStr, "Hz ");

    size = (uint8_t)metadata[14];
    utoa(size, (char*)str, 10);
    strcat(utilStr, "Sample:");
    strcat(utilStr, (char*)str);
    strcat(utilStr, "Bit");

    statusFromUtil();
}

// status line when playing: from the data stored in the GeoRAM, so it is
// right even after a reset (metadata[] only exists after an upload)
static void printPlayStatus(void)
{
    uint32_t bytes, rate;
    uint16_t secs;

    bytes = (uint8_t)subchsz[0] | ((uint32_t)(uint8_t)subchsz[1] << 8) |
            ((uint32_t)(uint8_t)subchsz[2] << 16);
    rate  = (uint8_t)byterate[0] | ((uint32_t)(uint8_t)byterate[1] << 8) |
            ((uint32_t)(uint8_t)byterate[2] << 16);
    secs = rate ? (uint16_t)(bytes / rate) : 0;

    utoa(sampleRates[sampleRate & 3], (char*)str, 10);
    strcpy(utilStr, (char*)str);
    strcat(utilStr, "Hz ");
    strcat(utilStr, sidDigimax ? "DigiMAX " : "SID ");
    utoa(secs / 60, (char*)str, 10);
    strcat(utilStr, (char*)str);
    strcat(utilStr, ":");
    if ((secs % 60) < 10)
        strcat(utilStr, "0");
    utoa(secs % 60, (char*)str, 10);
    strcat(utilStr, (char*)str);
    statusFromUtil();
}

// is there a plausible wave in the GeoRAM? (after checkSize())
static uint8_t waveInGeoram(void)
{
    uint32_t bytes, limit;

    bytes = (uint8_t)subchsz[0] | ((uint32_t)(uint8_t)subchsz[1] << 8) |
            ((uint32_t)(uint8_t)subchsz[2] << 16);
    limit = (uint8_t)maxmem[0] | ((uint32_t)(uint8_t)maxmem[1] << 8) |
            ((uint32_t)(uint8_t)maxmem[2] << 16);
    return bytes && !subchsz[3] && bytes <= limit && (byterate[0] | byterate[1] | byterate[2]);
}

uint8_t checkWAVE (void)
{
    waveOK = !memcmp(metadata, stringRIFF, 4) &&
             !memcmp(metadata + 8, stringWAVE, 4);
    return waveOK;
}

static void playWave (void)
{
    refreshMainScreen();
    STOPSIDP();
    if (noGeoram())
        return;
    checkSize();
    if (!waveInGeoram())
    {
        screenPrintSimpleDialog(apStrNoWave);
        return;
    }
    printPlayStatus();
    if (sampleRate < 2)
    {
        setScopeIRQ();         //1-->DigiMAX; 0-->SID
        screenPrintDialog2(keyControls);
        playData();
    }
    else
    {
        playDataSEI();         // screen off, Space = stop
    }
}

static void uploadWave (void)
{
    uint8_t i, bits, rateIdx;
    uint8_t gotFmt = 0;
    uint16_t nBytes, rate;

    if (noGeoram() || !selectFile())
        return;

    showStatus("Checking file");

    for (nBytes = 0; nBytes < 12; ++nBytes)
        metadata[nBytes] = utilReadByte();

    if (!checkWAVE())
    {
        showStatus("Not WAVE file");
        utilCloseFile();
        return;
    }

    for (;;)                                  // look for the fmt and data chunks
    {
        for (i = 0; i < 4; ++i) subchnk[i] = utilReadByte();
        for (i = 0; i < 4; ++i) subchsz[i] = utilReadByte();

        if (cbm_k_readst())                   // file ended: no data chunk
        {
            screenPrintSimpleDialog(apStrBadFmt);
            utilCloseFile();
            return;
        }

        if (!memcmp(subchnk, stringFMT, 4))
        {
            nBytes = (uint8_t)subchsz[0] | ((uint8_t)subchsz[1] << 8);
            if (subchsz[2] || subchsz[3] || nBytes < 16)
            {
                screenPrintSimpleDialog(apStrBadFmt);
                utilCloseFile();
                return;
            }
            for (i = 0; i < nBytes; ++i)      // keep the first 44 bytes only
            {
                rate = utilReadByte();
                if (i < sizeof(metadata))
                    metadata[i] = (char)rate;
            }
            if (nBytes & 1)                   // RIFF chunks are word aligned
                utilReadByte();

            byterate[0] = metadata[8];
            byterate[1] = metadata[9];
            byterate[2] = metadata[10];
            byterate[3] = metadata[11];
            gotFmt = 1;
        }
        else if (!memcmp(subchnk, stringDATA, 4))
        {
            break;
        }
        else
        {
            skip();                           // other chunks (LIST...)
        }
    }

    if (!gotFmt)
    {
        screenPrintSimpleDialog(apStrBadFmt);
        utilCloseFile();
        return;
    }

    rate = (uint8_t)metadata[4] | ((uint8_t)metadata[5] << 8);
    bits = metadata[14];
    for (rateIdx = 0; rateIdx < 4; ++rateIdx)
        if (sampleRates[rateIdx] == rate)
            break;

    if (metadata[0] != 1 || metadata[2] != 1 ||     // PCM, mono
        (bits != 8 && bits != 16) || rateIdx == 4)
    {
        printMetadata();
        screenPrintSimpleDialog(apStrWaveNotSupported);
        utilCloseFile();
        return;
    }

    sampleRate = rateIdx;

    strcpy(utilStr, "Upload:");
    strcat(utilStr, strFileName);
    strcat(utilStr, " Size:0x");
    utilAppendHex2(subchsz[2]);
    utilAppendHex2(subchsz[1]);
    utilAppendHex2(subchsz[0]);
    statusFromUtil();

    if (bits == 8)
        load8bit();              // the asm part also saves the size and format
    else
        load16bit();

    utilCloseFile();
    printMetadata();
    screenPrintSimpleDialog(apStrUploadComplete);
}

// ---------------------------------------------------------------- PRG / images

static void uploadPRG(void)
{
    uint8_t i;

    if (noGeoram() || !selectFile())
        return;

    showStatus("Checking file");

    BankLo = 0;
    BankHi = 0;
    for (i = 0; i < 171; ++i)
        POKE((0xde00 + i), downloader[i]);      // page 0: the downloader

    uploadPages(1, 0xff, 0);                    // the PRG follows from page 1
    utilCloseFile();

    if (geoFull)
        screenPrintSimpleDialog(apStrGeoramFull);
    else
        screenPrintSimpleDialog(apStrUploadedPRG);
}

static void uploadImage(void)
{
    if (noGeoram() || !selectFile())
        return;

    uploadPages(0, 0xff, 0);
    utilCloseFile();

    if (geoFull)
        screenPrintSimpleDialog(apStrGeoramFull);
    else
        screenPrintSimpleDialog(apStrUploadComplete);
}

static void loadText(void)
{
    if (!selectFile())
        return;

    showSEQ();
    utilCloseFile();
    screenInit();
}

// ---------------------------------------------------------------- SID

static void playSID (void)
{
    refreshMainScreen();
    if (!sidValid)
    {
        screenPrintSimpleDialog(apStrNoSID);
        return;
    }
    showStatus("Start playing SID");
    SIDINIT(); 						//Init SID
    SIDPLAY();						//Play 
}

static void stopSID (void)
{
    refreshMainScreen();
    showStatus("Stop playing SID");
    STOPSIDP();						//Stop Play 
}

// title and author of the PSID header (ASCII) as status line
static void showSIDInfo(void)
{
    uint8_t i, n, k, c;

    n = 0;
    k = 0;
    for (i = 0x16; i < 0x36 && SIDmetadata[i]; ++i)       // title
    {
        c = SIDmetadata[i];
        if (c > 64 && c < 97) c += 64;
        if (c > 95) c -= 32;
        utilStr[n++] = c;
        ++k;
    }
    utilStr[n++] = ' ';
    for (i = 0x36; i < 0x56 && SIDmetadata[i]; ++i)       // author
    {
        c = SIDmetadata[i];
        if (c > 64 && c < 97) c += 64;
        if (c > 95) c -= 32;
        utilStr[n++] = c;
        ++k;
        if (k > 36)
            break;
    }
    utilStr[n] = 0;
    statusFromUtil();
}

static void loadSID(void)
{
    uint16_t nBytes;
    uint8_t i;

    if (!selectFile())
        return;

    strcpy(utilStr, "Loading SID:");
    strcat(utilStr, strFileName);
    statusFromUtil();

    for (i = 0; i < 0x7e; ++i)
        SIDmetadata[i] = utilReadByte();

    if (memcmp(SIDmetadata, stringPSID, 4))
    {
        screenPrintSimpleDialog(apStrSIDNotPSID);
    }
    else if (SIDmetadata[0x0A] != 0x10 || SIDmetadata[0x0B] != 0x00 ||
             SIDmetadata[0x0C] != 0x10 || SIDmetadata[0x0D] != 0x03)
    {
        screenPrintSimpleDialog(apStrBadSIDaddr);
    }
    else
    {
        nBytes = utilRead(tuneAddr, SID_MAX_SIZE);
        if (nBytes == SID_MAX_SIZE && utilRead(buffer2, 1))
        {
            sidValid = 0;                 // $1000-$1fff now holds half a tune
            screenPrintSimpleDialog(apStrSIDTooBig);
        }
        else
        {
            sidValid = 1;
            showSIDInfo();
            screenPrintSimpleDialog(apStrLoadingComplete);
        }
    }
    utilCloseFile();
}

// ---------------------------------------------------------------- Koala

static void showKoalaImage (void)
{
    showKoala();
    screenInit();
}

static void slideShow (void)
{
	koalaCount = koalaCounter;
    downloadKoala();
    screenInit();
}

static uint8_t openKoala(void)         // file dialog + header check
{
    if (!selectFile())
        return 0;

    buffer2[0] = utilReadByte();
    buffer2[1] = utilReadByte();

    if (buffer2[0] != 0 || (buffer2[1] != 0x44 && buffer2[1] != 0x60))
    {
        utilCloseFile();
        screenPrintSimpleDialog(apStrNotKoala);
        return 0;
    }
    return 1;
}

static void loadKoala(void)
{
    uint8_t* p;
    uint16_t i;

    if (!openKoala())
        return;

    koalaFlag = 1;                     // from now on $2000-$3fff is the bitmap

    strcpy(utilStr, "Loading Koala:");
    strcat(utilStr, strFileName);
    statusFromUtil();

    p = koalaBmp;
    for (i = 0; i < 8000; ++i)
        *p++ = utilReadByte();

    copyDataColor();                   // screen, color RAM and background -> $e000

    utilCloseFile();
    showStatus("BMP Data at $2000 color Data at $E000");
    screenPrintSimpleDialog(apStrLoadingComplete);
}

static void uploadKoala(void)
{
    if (noGeoram())
        return;
    if (koalaCounter >= MAX_PICS)
    {
        screenPrintSimpleDialog(apStrMaxPics);
        return;
    }
    if (!openKoala())
        return;

    uploadPages(0, koalaCounter, koalaCounter + 1);   // one 16K block per image
    ++koalaCounter;
    utilCloseFile();
    screenPrintSimpleDialog(apStrUploadComplete);
}

// ---------------------------------------------------------------- Info

// ReadMe and SuperMon+ live in memory that the Koala bitmap overwrites
static void doInfo(void)
{
    if (koalaFlag)
        screenPrintSimpleDialog(apStrKoalaRam);
    else
        showINFO();
}

static void doSupermon(void)
{
    if (koalaFlag)
        screenPrintSimpleDialog(apStrKoalaRam);
    else
        goSupermon();
}

// ---------------------------------------------------------------- main screen

static const char* const welcomeText[] =
{
    "Plays 8/16 bit mono WAV (8-22 kHz)",
    "from GeoRAM/NeoRAM via SID or DigiMAX.",
    "Also SID tunes (4KB), Koala images,",
    "text files and PRG upload to GeoRAM.",
    NULL
};

static const char* const welcomeKeys[][2] =
{
    { "F", "PRG/image upload, SuperMon+, Reset" },
    { "W", "Wave: upload, play, output select" },
    { "S", "SID tune: load, play, stop" },
    { "K", "Koala: upload, show, slide show" },
    { "T", "Text file viewer" },
    { "H", "ReadMe and About" },
    { NULL, NULL }
};

static const char* const welcomeHelp[] =
{
    "In menus: letter, or cursors+Enter;",
    "STOP = back.",
    "Playing: Space=pause F1/F7=-5/+10s",
    "<-=rewind S=stop R=repeat +/-=screen",
    "F2=exit. At 16/22 kHz only Space=stop.",
    NULL
};

static void showWelcome(void)
{
    uint8_t y, i;

    y = 3;
    textcolor(COLOR_EXTRA);
    cputsxy(1, y, "GeoPlayer 1.1");
    textcolor(COLOR_FOREGROUND);
    cputs(" - GeoRAM audio player");
    y += 2;

    for (i = 0; welcomeText[i]; ++i)
        cputsxy(1, y++, welcomeText[i]);
    ++y;

    for (i = 0; welcomeKeys[i][0]; ++i)
    {
        textcolor(COLOR_EXTRA);
        cputsxy(1, y, welcomeKeys[i][0]);
        textcolor(COLOR_FOREGROUND);
        cputsxy(4, y++, welcomeKeys[i][1]);
    }
    ++y;

    for (i = 0; welcomeHelp[i]; ++i)
        cputsxy(1, y++, welcomeHelp[i]);
}

static void redrawMain(void)
{
    refreshMainScreen();
    showWelcome();
}

int main(void)
{  
	char key;
    uint8_t redraw;
    	
	fileDlgSetDriveNumber(8);
	
	memcpy((void*)(0x0400),(void*)&TITLEMAP,0x7f8);
	cursor(0);
	cgetc();
   
    koalaCounter=0;
    screenInit();
	redrawMain();
			
    if(!PEEK(0x02a6)){             //lda $02a6     ;0=NTSC,1=PAL           
			strcpy(utilStr,"Model:NTSC ");
			} 
		else {
			strcpy(utilStr,"Model:PAL "); 
			}
		
    if(!detectSID()){
		strcat(utilStr,"SID:6581 ");
	}
    else  {
		strcat(utilStr,"SID:8580 ");
		}
	       
	checkGeoram();                 // once: the result is kept in georam/maxmem
	showStatus(utilStr);
	screenBing();

	for (;;)
    {
        cursor(0);
        key = cgetc();
        redraw = 1;
        switch (key)
        {
        case 'f':
            execMenu(1, 2, aMainMenuEntries);
            break;
        case 'w':
            execMenu(6, 2, aPlayMenuEntries);
            break;
		case 's':
            execMenu(11, 2, aPlaySIDEntries);
            break;
		case 'k':
            execMenu(15, 2, aKoalaMenuEntries);
			screenInit();          // back from the bitmap: text screen and colors
            break;
		case 't':
            execMenu(21, 2, aTextMenuEntries);
            break;
        case 'h':
            execMenu(25, 2, aHelpMenuEntries);
            break;
        default:
            redraw = 0;
        }
        if (redraw)
            redrawMain();
	    refreshStatusLine();
    }
    return 0;
}
