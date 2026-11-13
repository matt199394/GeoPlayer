//cl65 -v -t c64 -T -O -I include -C geoplay.cfg geoplayMain.c screen.c FileDlg.c utility.c Dir.c geoplay-asm.s -o geoplayer.prg
//run: sys 16384
//Launch with SYS 57000 or SYS 57E3 once image is in neoram.

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
#define koalaColor ((unsigned char *)0xc000)
#define tuneAddr ((unsigned char *)0x1000)
#define RamPage ((unsigned char *)0xde00)
#define BankLo  (*(unsigned char *)0xdffe)
#define BankHi  (*(unsigned char *)0xdfff)

//#define POKE(addr,val) (*(unsigned char*) (addr) = (val))
//#define PEEK(addr) (*(unsigned char*) (addr))


/*
unsigned int SIDSIZE = (1024)*8; 			//8kb should be more than enough
unsigned int SIDLOAD = 0x4000;				//Make sure you offset your sid at $4000 using sidereloc -p 40

int main(void)
	{
	memcpy((void*)(SIDLOAD),(void*)&SIDFILE,SIDSIZE);	//Load music into memory 
	SIDINIT(); 						//Init SID
	SIDPLAY();						//Play 
	printf("Playing SID\n");	
	}
*/


unsigned char downloader[171] = {
	0xA2, 0x2A, 0xBD, 0x0D, 0xDE, 0x9D, 0xFF, 0xBF, 0xCA, 0xD0, 0xF7, 0x4C,
	0x00, 0xC0, 0xA9, 0x01, 0x8D, 0xFE, 0xDF, 0xA9, 0x00, 0x8D, 0xFF, 0xDF,
	0xA2, 0x00, 0xA0, 0x01, 0xBD, 0x00, 0xDE, 0x8D, 0x01, 0x08, 0xEE, 0x12,
	0xC0, 0xD0, 0x03, 0xEE, 0x13, 0xC0, 0xE8, 0xD0, 0xEF, 0xC8, 0x8C, 0xFE,
	0xDF, 0xC0, 0x98, 0xD0, 0xE7, 0x20, 0x74, 0xa4, 0x00, 0x0d, 0x08, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
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


unsigned char str [4];
unsigned char buffer4[4]={0,0,0,0};
unsigned char buffer2[2];
static char metadata[44];
uint16_t size;
uint8_t numOfPics;


static  const char stringRIFF[] = "riff";

static  const char stringWAVE[] = "wave";
static  const char stringFMT[] = "fmt ";
static  const char stringDATA[] = "data";
/*
static  const char* stringRIFF[] = "size: ";
static  const char* stringRIFF[] = "PCM ";
static  const char* stringRIFF[] = "Mono ";
static  const char* stringRIFF[] = "stereo";
static  const char* stringRIFF[] = "sample bits";
static  const char* stringRIFF[] = "sample rate";
static  const char* stringRIFF[] = "byterates";
*/

static  const char* keyControls[]=
{       
          "Space  -> Pause/Resume",
          "F1     -> Back 5 Seconds",
          "F7     -> Forward 10 Seconds",
          "<-     -> Rewind",
          "s      -> Stop",
          "+      -> Screen On",
          "-      -> Screen Off",
          "r      -> Repeat On/Off",
          "F2     -> Main Menu",
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

ScreenMenuEntry aHelpMenuEntries[] =
{
        {
            "About",
            showAbout,
            returnTrue
        },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aMainMenuEntries[] =
{       
		 {
            "Wave Uploader",
            uploadWave,
            returnTrue
        },
		{
            "SID Loader",
            loadSID,
            returnTrue
        },
		{
            "Koala Loader",
            loadKoala,
            returnTrue
        },
		
        {
            "PRG Uploader",
            uploadPRG,
            returnTrue
        },
		{
            "Image Uploader",
            uploadImage,
            returnTrue
        },
		{
            "Digi Output",
            digiOutput,
            returnTrue
        },
 
        {
            "Reset",
            utilReset,
            returnTrue
        },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aPlayMenuEntries[] =
{
        {
            "DIGIplay",
            playWave,
            returnTrue
        },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aPlaySIDEntries[] =
{
        {
            "Play SID",
            playSID,
            returnTrue
        },
		{
            "Stop SID",
            stopSID,
            returnTrue
        },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aKoalaMenuEntries[] =
{
        {
            "Show Koala Image",
            showKoalaImage,
            returnTrue
        },
		{
            "Geo Slide Show",
            slideShow,
            returnTrue
        },
		
        { NULL, NULL, 0 }
};

static void __fastcall__ execMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries)
{
    screenDoMenu(x, y, pMenuEntries);
    refreshMainScreen();
}


static void checkGeoram(void)
{

utilGeoram();

if(georam==5){
	maxmem[3]=0x00;
	strcat(utilStr, "GeoRAM Not Found");}
	
else if(georam==4){
	maxmem[3]=0x3f;
    strcat(utilStr, "GeoRAM:4Mb");}
    
else if(georam==3){
	maxmem[3]=0x1f;
    strcat(utilStr, "GeoRAM:2Mb");}
	
else if(georam==2){
	maxmem[3]=0x0f;
    strcat(utilStr, "GeoRAM:1Mb");}
	
else if(georam==1){
	maxmem[3]=0x07;
    strcat(utilStr, "GeoRAM:512Kb");}
}




static void digiOutput(void)
{
screenPrintDialog2(selectOutput);

sidDigimax=screenGetKey();

if (sidDigimax) {strcpy(strStatus,"Output: DigiMAx");}
    else {strcpy(strStatus,"Output: SID");}

    refreshStatusLine();
}


static void playWave (void)
{
        refreshMainScreen();
        screenPrintDialog2(keyControls);
		checkSize();
        playData();
}

static void playSID (void)
{
        refreshMainScreen();
        strcpy(strStatus, "Start playing SID");
		refreshStatusLine();
		SIDINIT(); 						//Init SID
		SIDPLAY();						//Play 
}

static void stopSID (void)
{
        refreshMainScreen();
        strcpy(strStatus, "Stop playing SID");
		refreshStatusLine();					
		STOPSIDP();						//Stop Play 
}


static void showKoalaImage (void)
{
        	showKoala();
			screenInit();						
}

static void slideShow (void)
{			
			
        	downloadKoala();
        
}

static void uploadWave (void)
{
    uint8_t i;
    uint8_t  rv;
//    uint16_t nPage;
    uint16_t nBytes;
    char *p;
//    char *p1;
    p = metadata;

	if(!maxmem[3]){screenPrintSimpleDialog(apStrGeoramNotPresent);
				}
	else{
    do
    {
        rv = fileDlg(strFileName, "a");
        if (!rv)
            return;

        rv = utilOpenFile(fileDlgGetDriveNumber(), strFileName);
        if (rv == 1)
            screenPrintSimpleDialog(apStrFileOpenError);
    }
    while (rv != OPEN_FILE_OK);

    refreshMainScreen();

    setStatus("Checking file");

    for (nBytes=0;nBytes<44;nBytes++)
    {
        metadata[nBytes]=utilReadByte();
    }
	
	
	i=0;
	while(metadata[i]==stringRIFF[i])++i;
	
	if (i==4){
		//strcpy(strStatus,"RIFF file");
		subchsz[0]=*(p+40);
        subchsz[1]=*(p+41);
        subchsz[2]=*(p+42);
        subchsz[3]=*(p+43);

        byterate[0]=*(p+28);
        byterate[1]=*(p+29);
        byterate[2]=*(p+30);
        byterate[3]=*(p+31);
		
		saveSize();
           
        strcpy(utilStr,"Uploading:");
        strcat(utilStr,strFileName);
		strcat(utilStr, " Size:");
		utilAppendHex2(*(p+42));
        utilAppendHex2(*(p+41));
        utilAppendHex2(*(p+40));
        strcpy(strStatus, utilStr);
		
        refreshStatusLine();
		
        load8bit ();
  
        utilCloseFile();
		
		if (metadata[20] == 1)
			strcpy(utilStr,"PCM "); 
		else if (metadata[20] == 6)
			strcpy(utilStr, "A-law ");
		else if (metadata[20] == 7)
			strcpy(utilStr, "Mu-law ");
		
		if (metadata[22] == 1)
			strcat(utilStr,"Mono "); 
		else if (metadata[22] == 2)
			strcat(utilStr, "Stereo "); 
		
		size = (metadata[24] | metadata[25] << 8);
        utoa(size, str, 10);
		strcat(utilStr,"Rate:");
        strcat(utilStr,str);
		 strcat(utilStr,"Hz ");
		 
		size =  metadata[34];
        utoa(size, str, 10);
      
		strcat(utilStr,"Sample:");
		strcat(utilStr,str);
		strcat(utilStr,"Bit");
		
        strcpy(strStatus, utilStr);
		
        refreshStatusLine();
		
        screenPrintSimpleDialog(apStrUploadComplete);	
	}
			
	else {
		strcpy(strStatus,"Not WAVE file");
		refreshStatusLine();
		utilCloseFile();
		}
		
	}
		
}


static void uploadPRG(void)
{
	uint8_t i; 
    uint8_t  rv;
    uint16_t nPage;
    uint16_t nBytes;

	if(!maxmem[3]){screenPrintSimpleDialog(apStrGeoramNotPresent);
				}
	else{
    do
    {
        rv = fileDlg(strFileName, "a");
        if (!rv)
            return;

        rv = utilOpenFile(fileDlgGetDriveNumber(), strFileName);
        if (rv == 1)
            screenPrintSimpleDialog(apStrFileOpenError);
    }
    while (rv != OPEN_FILE_OK);

    refreshMainScreen();

    setStatus("Checking file");
    utilReadByte();                       //remove 2 bytes address for prg files
    utilReadByte();
	
	POKE(0xdffe,0);
	POKE(0xdfff,0);
	for (i=0;i<171;++i)POKE((0xde00+i),downloader[i]);
   
    nPage = 1;
    for (;;)
    {
        BankLo = (nPage & 0x3f);
        BankHi = (nPage >> 6) & 0xff;

        nBytes = utilRead(RamPage, 0x100);
        if (!nBytes)
            break;

        nPage++;
        strcpy(utilStr, "Page ");
        utilAppendDecimal(nPage);
        strcpy(strStatus, utilStr);
        refreshStatusLine();
    }
    utilCloseFile();
	POKE(0xdffe,0);
	POKE(0xdfff,0);
    screenPrintSimpleDialog(apStrUploadedPRG);
	}
}

static void uploadImage(void)
{
    uint8_t  rv;
    uint16_t nPage;
    uint16_t nBytes;

	if(!maxmem[3]){screenPrintSimpleDialog(apStrGeoramNotPresent);
				}
	else{
    do
    {
        rv = fileDlg(strFileName, "a");
        if (!rv)
            return;

        rv = utilOpenFile(fileDlgGetDriveNumber(), strFileName);
        if (rv == 1)
            screenPrintSimpleDialog(apStrFileOpenError);
    }
    while (rv != OPEN_FILE_OK);

    refreshMainScreen();

    setStatus("Uploading Image");
    
	
	POKE(0xdffe,0);
	POKE(0xdfff,0);
	
    nPage = 0;
    for (;;)
    {
        BankLo = (nPage & 0x3f);
        BankHi = (nPage >> 6) & 0xff;

        nBytes = utilRead(RamPage, 0x100);
        if (!nBytes)
            break;

        nPage++;
        strcpy(utilStr, "Page ");
        utilAppendDecimal(nPage);
        strcpy(strStatus, utilStr);
        refreshStatusLine();
    }
	numOfPics=BankHi;
	++numOfPics;
    utilCloseFile();
	POKE(0xdffe,0);
	POKE(0xdfff,0);
    screenPrintSimpleDialog(apStrUploadComplete);
	}
}

static void loadSID(void)
{
	
    uint8_t  rv;
    uint16_t nBytes;
	uint16_t i;

    do
    {
        rv = fileDlg(strFileName, "a");
        if (!rv)
            return;

        rv = utilOpenFile(fileDlgGetDriveNumber(), strFileName);
        if (rv == 1)
            screenPrintSimpleDialog(apStrFileOpenError);
    }
    while (rv != OPEN_FILE_OK);

    refreshMainScreen();

    setStatus("Loading SID");
    
	for(i=0;i<0x7e;++i)utilReadByte();
	
	
    for (;;)
    {
   
        nBytes = utilRead(tuneAddr, 0x1000);
        if (!nBytes)
            break;
		
        strcpy(utilStr, "File Size: ");
        utilAppendDecimal(nBytes);
        strcpy(strStatus, utilStr);
		strcat(strStatus, " Bytes");
        refreshStatusLine();
    }
    utilCloseFile();
	
    screenPrintSimpleDialog(apStrUploadComplete);
	
}

static void loadKoala(void)
{
	
    uint8_t  rv;
	uint16_t i;
	
    do
    {
        rv = fileDlg(strFileName, "a");
        if (!rv)
            return;

        rv = utilOpenFile(fileDlgGetDriveNumber(), strFileName);
        if (rv == 1)
            screenPrintSimpleDialog(apStrFileOpenError);
    }
    while (rv != OPEN_FILE_OK);

    refreshMainScreen();

    setStatus("Loading Koala image");
    
	utilReadByte();
	utilReadByte();
	
	
   
       // nBytes = utilRead(koalaBmp, 8000);
		for(i=0;i<8000;++i){
			POKE((0x2000+i),utilReadByte());
			}
			
		
		copyDataColor();	
			

 
	utilCloseFile();
	strcpy(strStatus, "BMP Data at $2000 color Data at $E000");
    refreshStatusLine();
	
    screenPrintSimpleDialog(apStrUploadComplete);
	

	
}


int main(void)
{  
	
	char key;
    	
	fileDlgSetDriveNumber(8);
   
    screenInit();
	refreshMainScreen();
			
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
	       
		
	checkGeoram();
	strcpy(strStatus, utilStr);
    refreshStatusLine();
	screenBing();
    
 //   screenBing();

	for (;;)
    {
        //setStatus("Ready. Press <m> for Menu.");

        key = cgetc();
        switch (key)
        {
        case 'm':
            execMenu(1, 2, aMainMenuEntries);
            break;
        case 'd':
            execMenu(6, 2, aPlayMenuEntries);
            break;
		case 's':
            execMenu(11, 2, aPlaySIDEntries);
            break;
		case 'k':
            execMenu(15, 2, aKoalaMenuEntries);
            break;
        case 'h':
            execMenu(21, 2, aHelpMenuEntries);
            break;
        }
	refreshStatusLine();
    }
    return 0;
   
}
