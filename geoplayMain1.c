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

/*
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
*/
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


unsigned char str [4];
unsigned char buffer4[4]={0,0,0,0};
unsigned char buffer2[2];
static char metadata[44];
static char SIDmetadata[0x7e];
uint16_t size;
uint8_t flag;
uint8_t waveOK;
static uint8_t koalaCounter;


static  const char stringRIFF[] = {0x52, 0x49, 0x46, 0x46};  //"riff";

static  const char stringWAVE[] = {0x57, 0x41, 0x56, 0x45};		//"wave";
static  const char stringFMT[] = {0x66, 0x6D, 0x74, 0x20};			//"fmt ";
static  const char stringDATA[] = {0x64, 0x61, 0x74, 0x61};		//"data";
/*
static  const char* stringRIFF[] = "size: ";
static  const char* stringRIFF[] = "PCM ";
static  const char* stringRIFF[] = "Mono ";
static  const char* stringRIFF[] = "stereo";
static  const char* stringRIFF[] = "sample bits";
static  const char* stringRIFF[] = "sample rate";
static  const char* stringRIFF[] = "byterates";
*/
static  const char stringPSID[] = {0x50, 0x53, 0x49, 0x44,};	//"PSID"


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
		"SampleRate(Hz):8000/11025/16000",
        NULL
};

static const char* apStrSIDNotPSID[] =
{
        "Not PSID file!",
        NULL
};

static const char* apStrNotKoala[] =
{
        "Not Koala file!",
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

ScreenMenuEntry aHelpMenuEntries[] =
{
		{
            "ReadMe",
            showINFO,
            returnTrue
        },
	
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
            "SuperMon+",
            goSupermon,
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
            "Play Wave",
            playWave,
            returnTrue
        },
		{
            "Upload Wave",
            uploadWave,
			returnTrue
        },
		{
            "DigiMax/SID output",
            digiOutput,
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
		{
            "Load SID",
            loadSID,
            returnTrue
        },
        { NULL, NULL, 0 }
};

ScreenMenuEntry aKoalaMenuEntries[] =
{
		{
            "Upoad To GeoRam",
            uploadKoala,
            returnTrue
        },
		{
            "Load To C64Ram",
            loadKoala,
            returnTrue
        },
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


ScreenMenuEntry aTextMenuEntries[] =
{
        {
            "LoadTextFile ",
            loadText,
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
        STOPSIDP();
		printMetadata();
		checkSize();
		if (sampleRate<2){
			setScopeIRQ();         //1-->DigiMAX; 0-->SID
			screenPrintDialog2(keyControls);
			playData();
			}
		else if (sampleRate>=2){
		    playDataSEI();}
       
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
    uint16_t nBytes;
	
	checkGeoram();
   
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
	refreshStatusLine();
	
	   for (nBytes=0;nBytes<12;++nBytes)
		{
        metadata[nBytes]=utilReadByte();
		}
	
	if(checkWAVE()){
		

    flag=1;
	
	while(flag){
	
    for (nBytes=0;nBytes<4;++nBytes) subchnk[nBytes]=utilReadByte();
	for (nBytes=0;nBytes<4;++nBytes) subchsz[nBytes]=utilReadByte();
	i=0;
    while (stringFMT[i]==subchnk[i])++i;
    
    if (i==4){
		for(i=0;i<subchsz[0];++i)metadata[i]=utilReadByte();
		
		byterate[0]=metadata[8];
        byterate[1]=metadata[9];
        byterate[2]=metadata[10];
        byterate[3]=metadata[11];
/*		
		strcpy(utilStr,"subchsz[0] ");
	    utilAppendHex2(subchsz[0]);
		strcpy(strStatus, utilStr);
	    refreshStatusLine();
		while(1);
*/	
		}
	
		else {
        i=0;
		while (stringDATA[i]==subchnk[i])++i;
        
        if (i==4){
			flag=0;
		if ((metadata[0]!=1)||(metadata[2]!=1)
		//	||(metadata[4]==0x80)||(metadata[5]==0x3e)  //16rate
		//	||(metadata[4]==0x22)||(metadata[5]==0x56)  //22rate
			||(metadata[4]==0x44)||(metadata[5]==0xAC)	//44rate
			||(metadata[14]==24)  						//24 Bit per Sample
			||(metadata[14]==32)
			)
			{
			printMetadata();
			screenPrintSimpleDialog(apStrWaveNotSupported);
			utilCloseFile();			
			}
		
		else
		{	
			
			if (metadata[4]==0x40)sampleRate=0;
			else if (metadata[4]==0x11)sampleRate=1;
			else if (metadata[4]==0x80)sampleRate=2;
			else if (metadata[4]==0x22)sampleRate=3;
			

			strcpy(utilStr,"Upload:");
			strcat(utilStr,strFileName);
			strcat(utilStr, " Size:0x");
			utilAppendHex2(subchsz[2]);
			utilAppendHex2(subchsz[1]);
			utilAppendHex2(subchsz[0]);
			strcpy(strStatus, utilStr);
			refreshStatusLine();
			
			
			if(metadata[14]==8){
				
				saveSize();
				load8bit ();
				}
			else {
				
					load16bit ();
					//saveSize();
							}
			
  
			utilCloseFile();
			
			printMetadata();
			
			screenPrintSimpleDialog(apStrUploadComplete);
			}
		}
			else 
				{
				skip();
				flag=1;
				}
			
		}
	}

	}
	
	else {
		strcpy(strStatus,"Not WAVE file");
		refreshStatusLine();
		utilCloseFile();
		}	
	
	}
	

		
}

void printMetadata(void){
			strcpy(utilStr,"");
			if (metadata[0] == 1)
				strcpy(utilStr,"PCM "); 
			else if (metadata[0] == 6)
				strcpy(utilStr, "A-law ");
			else if (metadata[0] == 7)
				strcpy(utilStr, "Mu-law ");
		
			if (metadata[2] == 1)
				strcat(utilStr,"Mono "); 
			else if (metadata[2] == 2)
				strcat(utilStr, "Stereo "); 
		
			size = (metadata[4] | metadata[5] << 8);
			utoa(size, str, 10);
			strcat(utilStr,"Rate:");
			strcat(utilStr,str);
			strcat(utilStr,"Hz ");
		 
			size =  metadata[14];
			utoa(size, str, 10);
      
			strcat(utilStr,"Sample:");
			strcat(utilStr,str);
			strcat(utilStr,"Bit");
		
			strcpy(strStatus, utilStr);
		
			refreshStatusLine();
}

uint8_t checkWAVE (void)	
{
	
	uint8_t i;

	i=0;
	while (stringRIFF[i]==metadata[i] || stringWAVE[i]==metadata[i+8])++i;
	
	if (i==4){waveOK=1;
			 return 1;}
	else {waveOK=0;
		  return 0;}

}


	
	
static void uploadPRG(void)
{
	uint8_t i; 
    uint8_t  rv;
    uint16_t nPage;
    uint16_t nBytes;
	
	checkGeoram();

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
    //utilReadByte();                       //remove 2 bytes address for prg files
    //utilReadByte();
	
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

static void loadText(void)
{
    uint8_t  rv;
    //uint16_t nPage;
    //uint16_t nBytes;

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
   
	showSEQ();
	
	utilCloseFile();
	
	screenInit();

}

static void uploadImage(void)
{
    uint8_t  rv;
    uint16_t nPage;
    uint16_t nBytes;
	
	checkGeoram();

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

   

    //setStatus("Uploading Image");
    
	
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
        
        strcpy(utilStr,"Uploading:");
		strcat(utilStr,strFileName);
		strcat(utilStr, " Page ");
        utilAppendDecimal(nPage);
        strcpy(strStatus, utilStr);
        refreshStatusLine();
    }
	//numOfPics=BankHi;
	//++numOfPics;
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
	uint8_t n,k;
	
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

    //setStatus("Loading SID");
    strcpy(utilStr,"Loadind SID:");
	strcat(utilStr,strFileName);
	strcpy(strStatus, utilStr);
    refreshStatusLine();
    
	for(i=0;i<0x7e;++i){
	SIDmetadata[i]=utilReadByte();
	}
	i=0;
	while (SIDmetadata[i]==stringPSID[i])++i; 
	if (i!=4)
			{screenPrintSimpleDialog(apStrSIDNotPSID);}
		
	else{
	
		if (SIDmetadata[0x0A]!=0x10||SIDmetadata[0x0B]!=0x00||SIDmetadata[0x0C]!=0x10||SIDmetadata[0x0D]!=0x03)
		{screenPrintSimpleDialog(apStrBadSIDaddr);}
		else{
    for (;;)
    {
   
        nBytes = utilRead(tuneAddr, 0x1000);
        if (!nBytes)
            break;
		
        /*strcpy(utilStr, "File Size: ");
        utilAppendDecimal(nBytes);
        strcpy(strStatus, utilStr);
		strcat(strStatus, " Bytes");
        refreshStatusLine();
		*/
		
		k=0;
		i=0x16;
		n=0;
		while(SIDmetadata[i]){
		if(SIDmetadata[i]>64&&SIDmetadata[i]<97)SIDmetadata[i]=SIDmetadata[i]+64;
		if(SIDmetadata[i]>95)SIDmetadata[i]=SIDmetadata[i]-32;
		utilStr[n]=SIDmetadata[i];
		++i;
		++n;
		++k;
		}
		utilStr[n]=0;
		strcpy(strStatus,utilStr);
		strcat(strStatus, " ");
		
		i=0x36;
		n=0;
		while(SIDmetadata[i]){
		if(SIDmetadata[i]>64&&SIDmetadata[i]<97)SIDmetadata[i]=SIDmetadata[i]+64;
		if(SIDmetadata[i]>95)SIDmetadata[i]=SIDmetadata[i]-32;
		utilStr[n]=SIDmetadata[i];
		++i;
		++n;
		++k;
		if (k>36)break;
		}
		utilStr[n]=0;
		strcat(strStatus,utilStr);
		refreshStatusLine();
    }
    
    screenPrintSimpleDialog(apStrLoadingComplete);
	}
	}
	utilCloseFile();
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

    //setStatus("Loading Koala image");
    strcpy(utilStr,"Loading Koala:");
	strcat(utilStr,strFileName);
	strcpy(strStatus, utilStr);
    refreshStatusLine();
	
	
    
	buffer2[0]=utilReadByte();
	buffer2[1]=utilReadByte();
	
	if (buffer2[0] != 0 || (buffer2[1] != 0x44 && buffer2[1] != 0x60)) {
    utilCloseFile();
	screenPrintSimpleDialog(apStrNotKoala);
	}
	else{
	
   
       // nBytes = utilRead(koalaBmp, 8000);
		for(i=0;i<8000;++i){
			POKE((0x2000+i),utilReadByte());
			}
			
		
		copyDataColor();	
			

 
	utilCloseFile();
	strcpy(strStatus, "BMP Data at $2000 color Data at $E000");
    refreshStatusLine();
	
    screenPrintSimpleDialog(apStrLoadingComplete);
	}

	
}

static void uploadKoala(void)
{ 
    uint8_t  rv;
    uint16_t nPage;
    uint16_t nBytes;
	
	checkGeoram();

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

    
	buffer2[0]=utilReadByte();
	buffer2[1]=utilReadByte();
	
	if (buffer2[0] != 0 || (buffer2[1] != 0x44 && buffer2[1] != 0x60)) {
    utilCloseFile();
	screenPrintSimpleDialog(apStrNotKoala);
	}
	else{

	//POKE(0xdffe,0);
	//POKE(0xdfff,koalaCounter);
	
    nPage = 0;
    for (;;)
    {
        BankLo = (nPage & 0x3f);
        BankHi = koalaCounter;     //(nPage >> 6) & 0xff;

        nBytes = utilRead(RamPage, 0x100);
        if (!nBytes)
            break;

        nPage++;
        
        strcpy(utilStr,"Uploading:");
		strcat(utilStr,strFileName);
		strcat(utilStr, " Page ");
        utilAppendDecimal(nPage);
		strcat(utilStr," Pic n:");
		utilAppendDecimal(koalaCounter+1);
        strcpy(strStatus, utilStr);
		
        refreshStatusLine();
    }
	++koalaCounter;
    utilCloseFile();
	POKE(0xdffe,0);
	POKE(0xdfff,0);
    screenPrintSimpleDialog(apStrUploadComplete);
	}
	}
}


int main(void)
{  
	
	char key;
    	
	fileDlgSetDriveNumber(8);
	
	memcpy((void*)(0x0400),(void*)&TITLEMAP,0x7f8);
	//makecolour1();
	cgetc();
   
    koalaCounter=0;
    screenInit();
	refreshMainScreen();
	//cursor (0);
			
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
			screenInit();
			refreshMainScreen();
            break;
		case 't':
            execMenu(21, 2, aTextMenuEntries);
            break;
        case 'h':
            execMenu(25, 2, aHelpMenuEntries);
            break;
        }
	refreshStatusLine();
    }
    return 0;
   
}
