#include <c64.h>
#include <stdint.h>
#include <conio.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>

#include "geoplay.h"
#include "util.h"

char strStatus[41];

const char* apStrAbout[] =
{
        "Version 1.1", 
        "",
        "(Compiled: " __DATE__ " " __TIME__ ")",
        "GeoPlayer(C) 2021 Matteo Angelini",
		"Based on:",
		"GeoDigi(C) 2021 Greg Nacu",
        "GeoUpload(C) 2009 Thomas Giesel",
        NULL
};

void screenInit(void)
{
	bgcolor(COLOR_BACKGROUND);
    bordercolor(COLOR_BACKGROUND);
    textcolor(COLOR_FOREGROUND);
    clrscr();
}


void screenBing(void)
{
    unsigned f;

    SID.amp = 0x0f;

    // switch of prev. tone, init some values
    memset(&(SID.v1), 0, 3 * sizeof(SID.v1));

    SID.v1.ad =
    SID.v2.ad = 0x08;

    SID.v2.freq = 0x3900;

    SID.v1.ctrl =
    SID.v2.ctrl = 0x11;

    for (f = 0x3800; f != 0x4400; ++f)
        SID.v1.freq = f;

    memset(&(SID.v1), 0, 3 * sizeof(SID.v1));
}


void __fastcall__ screenPrintSimpleDialog(const char* apStrLines[])
{
    screenPrintDialog(apStrLines, BUTTON_ENTER);
}

uint8_t __fastcall__ screenPrintDialog(const char* apStrLines[], uint8_t flags)
{
    uint8_t y, t;
    uint8_t nLines;
    uint8_t nLongestLength = 1;
    uint8_t xStart, xEnd, yStart, yEnd;

    for (y = 0; apStrLines[y]; ++y)
    {
        t = strlen(apStrLines[y]);
        if (t > nLongestLength)
            nLongestLength = t;
		if (nLongestLength<=10)nLongestLength=10;
    }
    nLines = y;

    if (nLongestLength > 38)
        nLongestLength = 38;

    nLongestLength += 2;
    xStart = 20 - nLongestLength / 2;
    xEnd = 20 + nLongestLength / 2;
    yStart = 8 - nLines / 2;
    yEnd = 8 + nLines / 2 + 9;

    // Top line
    y = yStart;
    screenPrintTopLine(xStart, xEnd, y);
    screenPrintFreeLine(xStart, xEnd, ++y);
    cputsxy(xStart + 1, y, "GeoPlayer");
    screenPrintSepLine(xStart, xEnd, ++y);

    // some lines
    for (++y; y < yEnd; ++y)
        screenPrintFreeLine(xStart, xEnd, y);
    // Bottom line
    screenPrintBottomLine(xStart, xEnd, y);

    // Write the text lines
    yStart += 4;
    ++xStart;
    for (y = 0; y < nLines; ++y)
    {
        t = strlen(apStrLines[y]);
        if (t > 38)
            continue;

        cputsxy(xStart, yStart++, apStrLines[y]);
    }

    y = yEnd - 3;
    if (flags & BUTTON_ENTER)
        screenPrintButton(xEnd - 7, yEnd - 3, "Enter");

    if (flags & BUTTON_STOP)
        screenPrintButton(xStart, yEnd - 3, "Stop");

    screenBing();

    if (flags)
        return screenWaitKey(flags);

    return 0;
}

void __fastcall__ screenPrintDialog2(const char* apStrLines[])
{
    uint8_t y, t;
    uint8_t nLines;
    uint8_t nLongestLength = 1;
    uint8_t xStart, xEnd, yStart, yEnd;

    for (y = 0; apStrLines[y]; ++y)
    {
        t = strlen(apStrLines[y]);
        if (t > nLongestLength)
            nLongestLength = t;
		if (nLongestLength<=12)nLongestLength=12;
    }
    nLines = y;

    if (nLongestLength > 38)
        nLongestLength = 38;

    nLongestLength += 2;
    xStart = 20 - nLongestLength / 2;
    xEnd = 20 + nLongestLength / 2;
    yStart = 8 - nLines / 2;
    yEnd = 8 + nLines / 2 + 6;

    // Top line
    y = yStart;
    screenPrintTopLine(xStart, xEnd, y);
    screenPrintFreeLine(xStart, xEnd, ++y);
    cputsxy(xStart + 1, y, "Keys Option:");
    screenPrintSepLine(xStart, xEnd, ++y);

    // some lines
    for (++y; y < yEnd; ++y)
        screenPrintFreeLine(xStart, xEnd, y);
    // Bottom line
    screenPrintBottomLine(xStart, xEnd, y);

    // Write the text lines
    yStart += 4;
    ++xStart;
    for (y = 0; y < nLines; ++y)
    {
        t = strlen(apStrLines[y]);
        if (t > 38)
            continue;

        cputsxy(xStart, yStart++, apStrLines[y]);
    }

    y = yEnd - 3;
    
    screenBing();

    //return 0;
}

void screenPrintTopLine(uint8_t xStart, uint8_t xEnd, uint8_t y)
{
    --xEnd;

    cputcxy(xStart, y, 0xb0);
    chline(xEnd - xStart);
    cputc(0xae);
}



void screenPrintSepLine(uint8_t xStart, uint8_t xEnd, uint8_t y)
{
    --xEnd;

    cputcxy(xStart, y, 0xab);
    chline(xEnd - xStart);
    cputc(0xb3);
}

uint8_t __fastcall__ screenPrintTwoLinesDialog(const char* p1, const char* p2)
{
    const char* apStrLines[3];
    apStrLines[0] = p1;
    apStrLines[1] = p2;
    apStrLines[2] = NULL;
    return screenPrintDialog(apStrLines, BUTTON_ENTER | BUTTON_STOP);
}


void screenPrintBottomLine(uint8_t xStart, uint8_t xEnd, uint8_t y)
{
    --xEnd;

    cputcxy(xStart, y, 0xad);
    chline(xEnd - xStart);
    cputc(0xbd);
}



void screenPrintFreeLine(uint8_t xStart, uint8_t xEnd, uint8_t y)
{
    cputcxy(xStart, y, 0x7d);
    cclear(xEnd - xStart - 1);
    cputc(0x7d);
}

void screenPrintButton(uint8_t x, uint8_t y, const char* pStrLabel)
{
    uint8_t len;
    uint8_t xEnd;

    len = strlen(pStrLabel);
    xEnd = x + len + 1;

    screenPrintTopLine(x, xEnd, y++);

    cputcxy(x, y++, 0x7d);
    cputs(pStrLabel);
    cputc(0x7d);

    screenPrintBottomLine(x, xEnd, y);
}



void screenPrintFrame(void)
{
    uint8_t y;

    // Top line
    screenPrintTopLine(0, 39, 0);
    // 1 text line
    screenPrintFreeLine(0, 39, 1);
    // separation line with "step"
    screenPrintSepLine(0, 39, 2);

    // some free lines
    for (y = 3; y < 22; ++y)
        screenPrintFreeLine(0, 39, y);
    // separation line
    screenPrintSepLine(0, 39, 22);
    // 1 text line
    screenPrintFreeLine(0, 39, 23);
    // Bottom line
    screenPrintBottomLine(0, 39, 24);
}


void screenPrintBox(uint8_t x, uint8_t y, uint8_t w, uint8_t h)
{
    uint8_t i;

    --w;

    // Top line
    screenPrintTopLine(x, x + w, y);

    for (i = h - 2; i; --i)
    {
        // text line
        screenPrintFreeLine(x, x + w, ++y);
    }

    // Bottom line
    screenPrintBottomLine(x, x + w, ++y);
}

void refreshMainScreen(void)
{
    screenPrintFrame();

    // menu entries
    gotoxy (1, 1);
    textcolor(COLOR_EXTRA);
    cputc('F');
    textcolor(COLOR_FOREGROUND);
    cputs("ile ");

    textcolor(COLOR_EXTRA);
    cputc('W');
    textcolor(COLOR_FOREGROUND);
    cputs("ave ");
	
	textcolor(COLOR_EXTRA);
    cputc('S');
    textcolor(COLOR_FOREGROUND);
    cputs("ID ");
	
	textcolor(COLOR_EXTRA);
    cputc('K');
    textcolor(COLOR_FOREGROUND);
    cputs("oala ");
	
	textcolor(COLOR_EXTRA);
    cputc('T');
    textcolor(COLOR_FOREGROUND);
    cputs("ext ");
	
    textcolor(COLOR_EXTRA);
    cputc('H');
    textcolor(COLOR_FOREGROUND);
    cputs("elp");
}

uint8_t returnTrue(void)
{
   return 1;
}

void showAbout(void)
{
    screenPrintSimpleDialog(apStrAbout);
}


void __fastcall__ screenPrintMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries,
                                  uint8_t nSelected, uint8_t bPrintFrame)
{
    uint8_t nEntry, nEntries;
    uint8_t tmp;
    uint8_t len;
    const ScreenMenuEntry* pEntry;
    const char* pStr;

    // calculate length of longest entry
    len = 2;
    for (nEntry = 0; (pStr = pMenuEntries[nEntry].pStrLabel); ++nEntry)
    {
        tmp = strlen(pStr);
        if (tmp > len)
            len = tmp;
    }
    len += 2;
    nEntries = nEntry;

    if (bPrintFrame)
    {
        screenPrintBox(x, y, len + 2, nEntries + 2);
    }

    pEntry = pMenuEntries;
    for (nEntry = 0; nEntry != nEntries; ++nEntry)
    {
        gotoxy(x + 1, ++y);

        pStr = pEntry->pStrLabel;

        if (nEntry == nSelected)
            revers(1);

        cputc(' ');
        if (pEntry->pCheckFunction())
        {
            textcolor(COLOR_EXTRA);
            cputc(*pStr);
            textcolor(COLOR_FOREGROUND);
            cputs(pStr + 1);
        }
        else
        {
            textcolor(COLOR_GRAY1);
            cputs(pStr);
        }
        cclear(len + x - wherex() + 1);

        revers(0);
        ++pEntry;
    }
    textcolor(COLOR_FOREGROUND);
}



void __fastcall__ screenDoMenu(uint8_t x, uint8_t y,
                               const ScreenMenuEntry* pMenuEntries)
{
    uint8_t nEntry, nEntries;
    uint8_t nSelected;
    char key;

    screenPrintMenu(x, y, pMenuEntries, nSelected, 1);

    // count the entries
    nEntries = 0;
    for (nEntry = 0; pMenuEntries[nEntry].pStrLabel; ++nEntry)
        ++nEntries;

    nSelected = 0;

    do
    {
        screenPrintMenu(x, y, pMenuEntries, nSelected, 0);
        key = cgetc();

        switch (key)
        {
        case CH_CURS_UP:
            if (nSelected)
                --nSelected;
            else
                nSelected = nEntries - 1;
            break;

        case CH_CURS_DOWN:
            if (++nSelected == nEntries)
                nSelected = 0;
            break;

        case CH_ENTER:
            if (pMenuEntries[nSelected].pCheckFunction())
            {
                pMenuEntries[nSelected].pFunction();
                return;
            }
            break;

        default:
            for (nEntry = 0; nEntry != nEntries; ++nEntry)
            {
                if (key == tolower(pMenuEntries[nEntry].pStrLabel[0]) &&
                        pMenuEntries[nEntry].pCheckFunction())
                {
                    screenPrintMenu(x, y, pMenuEntries, nEntry, 0);
                    pMenuEntries[nEntry].pFunction();
                    return;
                }
            }
        }
    } while (key != CH_STOP);
}

uint8_t __fastcall__ screenWaitKey(uint8_t flags)
{
    char key;

    for (;;)
    {
        key = cgetc();

        if ((flags & BUTTON_ENTER) && key == CH_ENTER)
            return BUTTON_ENTER;

        if ((flags & BUTTON_STOP) && key == CH_STOP)
            return BUTTON_STOP;
    }
}

uint8_t __fastcall__ screenGetKey(void)
{
    char key;

    for (;;)
    {
        key = cgetc();

        if (key == 0x53)  //S key
            return 0;

        if (key == 0x44)   //D key
            return 1;
    }
}

void refreshStatusLine(void)
{
    gotoxy (1, 23);
    cputs(strStatus);
    cclear(39 - wherex());
}

void __fastcall__ setStatus(const char* pStrStatus)
{
    strncpy(strStatus, pStrStatus, sizeof(strStatus - 1));
    strStatus[sizeof(strStatus) - 1] = '\0';
    refreshStatusLine();
}

