#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <inttypes.h>

uint8_t mem[65536];
int current_base;

uint16_t wmem(int addr) { return *(uint16_t *)(mem+addr); }
uint32_t dmem(int addr) { return *(uint32_t *)(mem+addr); }

char depend_names[16][9];

char *module_name(int num) {
    int rel = wmem(current_base-18-2*num); 
    if (rel) return mem + rel - 14;
    else return depend_names[num];
}

char *proc_name(char *module_name, int procnum) {
  if (strncmp(module_name,"TEXTS", 8) == 0 && procnum <= 27) {
    char *names[] = { "TEXTS",
       "ReadChar", "ReadString", "ReadInt", "ReadCard", "ReadLong", "ReadReal", "ReadLn",
      "WriteChar","WriteString","WriteInt","WriteCard","WriteLong","WriteReal","WriteLn",
      "ReadLine", "ReadAgain", "Done", "EOLN", "EOT", "Col", "SetCol", "TextFile",
      "OpenText", "CreateText", "CloseText", "ConnectDriver", "Init"
    };
    return names[procnum];
  } else if (strncmp(module_name,"INOUT", 8) == 0 && procnum <= 17) {
    char *names[] = { "INOUT",
      "OpenInput","OpenOutput","CloseInput","CloseOutput",
       "Read",           "ReadString", "ReadInt", "ReadCard",
      "Write","WriteLn","WriteString","WriteInt","WriteCard",
      "WriteHex","WriteOct","ReadRead","WriteReal"
    };
    return names[procnum];
  } else if (strncmp(module_name,"FILES", 8) == 0 && procnum <= 21) {
    char *names[] = { "FILES",
      "Open","Create","Close","Delete","Rename","GetName","FileSize","EOF",
       "ReadByte", "ReadWord", "ReadRec", "ReadBytes",
      "WriteByte","WriteWord","WriteRec","WriteBytes",
      "Flush","NextPos","SetPos","NoTrailer","ResetSys"
    };
    return names[procnum];
  } else if (strncmp(module_name,"TERMINAL", 8) == 0 && procnum <= 16) {
    char *names[] = { "TERMINAL",
      "ReadChar","BusyRead","ReadAgain","ReadLine","WriteChar","WriteLn","WriteString",
      "ClearScreen","GotoXY","ClearToEOL","InsertLine","DeleteLine","Highlight","Normal",
      "InitScreen","ExitScreen"
    };
    return names[procnum];
  } else if (strncmp(module_name,"COMLINE", 8) == 0 && procnum <= 3) {
    char *names[] = { "COMLINE",
      "RedirectInput","RedirectOutput","PromptFor"
    };
    return names[procnum];
  } else if (strncmp(module_name,"MATHLIB", 8) == 0 && procnum <= 9) {
    char *names[] = { "MATHLIB",
      "Sqrt","Exp","Ln","Sin","Cos","ArcTan","Entier","Randomize","Random"
    };
    return names[procnum];
  } else if (strncmp(module_name,"STRINGS", 8) == 0 && procnum <= 7) {
    char *names[] = { "STRINGS",
      "Length","Pos","Insert","Delete","Append","Copy","CAPS"
    };
    return names[procnum];
  } else if (strncmp(module_name,"CONVERT", 8) == 0 && procnum <= 8) {
    char *names[] = { "CONVERT",
      "StrToInt","StrToCard","StrToLong","StrToReal",
      "IntToStr","CardToStr","LongToStr","RealToStr"
    };
    return names[procnum];
  } else if (strncmp(module_name,"DOUBLES", 8) == 0 && procnum <= 4) {
    char *names[] = { "DOUBLES",
      "ReadDouble","WriteDouble","StrToDouble","DoubleToStr"
    };
    return names[procnum];
  } else if (strncmp(module_name,"PROCESSE", 8) == 0 && procnum <= 5) {
    char *names[] = { "PROCESSES",
      "StartProcess","SEND","WAIT","Awaited","Init"
    };
    return names[procnum];
  } else if (strncmp(module_name,"LOADER", 8) == 0 && procnum <= 1) {
    char *names[] = { "LOADER",
      "Call"
    };
    return names[procnum];
  } else {
    static char name[8];
    sprintf(name,"proc%d",procnum);
    return name;
  }
}

void decode38(int addr)
{
    int num = wmem(addr);
    for (int i=0;i<3;i++) {
        int mod = num % 38;
        printf("%c",mod < 26 ? mod+'A' : mod < 36 ? mod-26+'0' : ' ');
        num = num / 38;
    }
}

void call_rel(int IP)
{
    int disp = mem[IP++];
    printf(".. load immediate string \"");
    for (int i=0; i<disp; i++) {
        if (mem[IP+i]<' ') printf("\\x%02x",mem[IP+i]);
        else printf("%c",mem[IP+i]);
    }
    printf("\"");
}

int longreal_opcode(int IP)
{
    switch (mem[IP++]) {
        case 0: printf("ll_longreal %+d",(int8_t)mem[IP++]); break; // Load  Local    LONGREAL
        case 1: printf("lg_longreal %d",mem[IP++]); break; // Load  Global   LONGREAL
        case 2: printf("ls_longreal %d",mem[IP++]); break; // Load  Stack    LONGREAL
        case 3: printf("le_longreal %.8s.LONGREAL%d",module_name(mem[IP]),mem[IP+1]); IP+=2; break; // Load  External LONGREAL
        case 4: printf("sl_longreal %+d",(int8_t)mem[IP++]); break; // Store Local    LONGREAL
        case 5: printf("sg_longreal %d",mem[IP++]); break; // Store Global   LONGREAL
        case 6: printf("ss_longreal %d",mem[IP++]); break; // Store Stack    LONGREAL
        case 7: printf("se_longreal %.8s.LONGREAL%d",module_name(mem[IP]),mem[IP+1]); IP+=2; break; // Store External LONGREAL
        case 8: printf("lx_longreal"); break; // Load  Indexed  LONGREAL
        case 9: printf("sx_longreal"); break; // Store Indexed  LONGREAL
        case 10: printf("fctleave_longreal %d",mem[IP++]); break;// LONGREAL_FCT_LEAVE
    }
    return IP;
}

int extended_opcode(int IP)
{
    switch (mem[IP++]) {
        case 0: printf("drop"); break; // DROP
        case 1: printf("save_int_and_clear"); break; // PUSH_INT_FLAG and DISABLE INT
        case 2: printf("restore_int"); break; // POP_INT_FLAG
        case 3: printf("long_negate"); break; // LONG_NEGATE
        case 4: printf("build_field_mask"); break; // BUILD FIELD MASK
        case 5: printf("ALLOCATE"); break; // ALLOCATE
        case 6: printf("DEALLOCATE"); break; // DEALLOCATE
        case 7: printf("MARK"); break; // MARK
        case 8: printf("RELEASE"); break; // RELEASE
        case 9: printf("FREEMEM"); break; // FREEMEM
        case 10: printf("TRANSFER"); break; // TRANSFER
        case 11: printf("IOTRANSFER"); break; // IOTRANSFER
        case 12: printf("NEWPROCESS"); break; // NEWPROCESS
        case 13: printf("BIOS"); break; // BIOS
        case 14: printf("MOVE"); break; // MOVE
        case 15: printf("FILL"); break; // FILL
        case 16: printf("INP"); break; // INP
        case 17: printf("OUT"); break; // OUT
        case 18: printf("reserve_string"); break; // RESERVE STRING
// new opcodes
        case 20: printf("assert (line %d)",wmem(IP)); IP+=2; break; // ASSERT
        case 21: printf("addc"); break;
        case 22: printf("subc"); break;
        case 23: printf("mulc"); break;
        case 24: printf("divc"); break;
        case 25: printf("load carry"); break;
        case 26: printf("clc"); break;
    }
    return IP;
}

int opcode_size[256] = {
    1,1,2,1, 1,1,1,1, 2,2,2,3, 2,1,1,1,
    1,2,3,1, 1,1,1,1, 2,2,2,3, 2,1,1,1,
    1,1,1,1, 1,1,1,1, 1,1,1,1, 2,2,2,3,
    1,1,1,1, 1,1,1,1, 1,1,1,1, 2,2,2,3,
    2,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1, 
    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
    2,2,2,3, 2,2,2,2, 1,1,1,1, 2,2,3,5,
    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,2,2,
    2,2,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1,
    1,1,1,1, 1,1,1,1, 1,1,1,1, 1,7,1,3, 
    1,1,1,1, 2,1,1,1, 1,1,1,1, 1,1,2,2, 
    3,3,2,2, 2,2,1,1, 1,1,1,1, 2,2,2,3,
    2,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1
};


void unassemble(int IP, int toIP)
{
    int i;
    while (IP < toIP) {
        int opcode = mem[IP];
        printf("%04x  ",IP);
        for (i=0; i<opcode_size[opcode]; i++) printf("%02x ",mem[IP+i]);
        if (opcode != 0x8c)
            for (; i<3; i++) printf("   ");
        printf(" ");
        IP++;
        switch (opcode) {
		case 0x00: printf("Error16"); break; // Error 16
		case 0x01: printf("Raise"); break; // RAISE
		case 0x02: printf("load proc_addr proc%d",mem[IP++]); break; // LOAD_PROC_ADDR n
		case 0x03: printf("load param1"); break; // LOAD_PARAM1 (IX+6)
		case 0x04: printf("load param2"); break; // LOAD_PARAM2 (IX+8)
		case 0x05: printf("load param3"); break; // LOAD_PARAM3 (IX+10)
		case 0x06: printf("load param4"); break; // LOAD_PARAM4 (IX+12)
		case 0x07: printf("load param5"); break; // LOAD_PARAM5 (IX+14)
		case 0x08: printf("load local dword%+d",(int8_t)mem[IP++]); break; // LLD n           Load Local  Double Word ( n<0 : LOCAL_VAR, n>0 : PARAM)
		case 0x09: printf("load global dword%d",mem[IP++]); break; // LGD n           Load Global Double Word
		case 0x0A: printf("load stack dword %d",mem[IP++]); break; // LSD n           Load Stack  Double Word
		case 0x0B: printf("load %.8s.dword%d",module_name(mem[IP]),mem[IP+1]); IP+=2; break; // LED n m         Load External Double Word
		case 0x0C: printf("load %.8s.word%d",module_name(mem[IP]/16),mem[IP]%16); IP++; break; // EXTERN_LOAD mn       (m : module (high nibble), n var number)
		case 0x0D: printf("load indexed byte"); break; // LXB             Load Indexed Byte
		case 0x0E: printf("load indexed word"); break; // LXW             Load Indexed Word
		case 0x0F: printf("load indexed dword"); break; // LXD             Load Indexed Double word

		case 0x10: printf("load outer frame"); break; // LOAD (IX)
		case 0x11: printf("load outer frame %d",mem[IP++]); break; // LOAD ((((IX)))) n times
		case 0x12: IP=longreal_opcode(IP); break; // LONGREAL_OPCODE op n
		case 0x13: printf("store param1"); break; // SET_PARAM1 (IX+6)
		case 0x14: printf("store param2"); break; // SET_PARAM2 (IX+8)
		case 0x15: printf("store param3"); break; // SET_PARAM3 (IX+10)
		case 0x16: printf("store param4"); break; // SET_PARAM4 (IX+12)
		case 0x17: printf("store param5"); break; // SET_PARAM5 (IX+14)
		case 0x18: printf("store local dword %+d",(int8_t)mem[IP++]); break; // SLD n           Store Local  Double Word
		case 0x19: printf("store global dword %d",mem[IP++]); break; // SGD n           Store Global Double Word
		case 0x1A: printf("store stack dword %d",mem[IP++]); break; // SSD n           Store Stack  Double Word
		case 0x1B: printf("store %.8s.dword%d",module_name(mem[IP]),mem[IP+1]); IP+=2; break; // SED n m        Store External Double Word
		case 0x1C: printf("store %.8s.word%d",module_name(mem[IP]/16),mem[IP]%16); IP++; break; // SED mn       (m : module (high nibble), n var number)
		case 0x1D: printf("store indexed byte"); break; // SXB             Store Indexed Byte
		case 0x1E: printf("store indexed word"); break; // SXW             Store Indexed Word
		case 0x1F: printf("store indexed dword"); break; // SXD             Store Indexed Double word

		case 0x20: printf("dup"); break; // DUP
		case 0x21: printf("swap"); break; // SWAP
		case 0x22: printf("load local word-2"); break; // LLW2        Load Local Word -2
		case 0x23: printf("load local word-3"); break; // LLW3        Load Local Word -3
		case 0x24: printf("load local word-4"); break; // LLW4        Load Local Word -4
		case 0x25: printf("load local word-5"); break; // LLW5        Load Local Word -5
		case 0x26: printf("load local word-6"); break; // LLW6        Load Local Word -6
		case 0x27: printf("load local word-7"); break; // LLW7        Load Local Word -7
		case 0x28: printf("load local word-8"); break; // LLW8        Load Local Word -8
		case 0x29: printf("load local word-9"); break; // LLW9        Load Local Word -9
		case 0x2A: printf("load local word-10"); break; // LLW10       Load Local Word -10
		case 0x2B: printf("load local word-11"); break; // LLW11       Load Local Word -11
		case 0x2C: printf("load local word %+d",(int8_t)mem[IP++]); break; // LLW n       Load Local Word  (n<0 : LOCAL_VAR, n>0 : PARAM)
		case 0x2D: printf("load global word %d",mem[IP++]); break; // LGW n       Load Global Word n
		case 0x2E: printf("load stack word %d",mem[IP++]); break; // LSW n       Load Stack Word n
		case 0x2F: printf("load %.8s.word%d",module_name(mem[IP]),mem[IP+1]); IP+=2; break; // LEW n m         Load External Word

		case 0x30: printf("copy block"); break; // MOVB        Copy Block
		case 0x31: printf("copy string"); break; // MOVS        Copy String
		case 0x32: printf("store local word-2"); break; // SLW2        Store Local Word -2
		case 0x33: printf("store local word-3"); break; // SLW3        Store Local Word -3
		case 0x34: printf("store local word-4"); break; // SLW4        Store Local Word -4
		case 0x35: printf("store local word-5"); break; // SLW5        Store Local Word -5
		case 0x36: printf("store local word-6"); break; // SLW6        Store Local Word -6
		case 0x37: printf("store local word-7"); break; // SLW7        Store Local Word -7
		case 0x38: printf("store local word-8"); break; // SLW8        Store Local Word -8
		case 0x39: printf("store local word-9"); break; // SLW9        Store Local Word -9
		case 0x3A: printf("store local word-10"); break; // SLW10       Store Local Word -10
		case 0x3B: printf("store local word-11"); break; // SLW11       Store Local Word -11
		case 0x3C: printf("store local word %+d",(int8_t)mem[IP++]); break; // SLW n       Store Local Word  (n<0 : LOCAL_VAR, n>0 : PARAM)
		case 0x3D: printf("store global word %d",mem[IP++]); break; // SGW n       Store Global Word n
		case 0x3E: printf("store stack word %d",mem[IP++]); break; // SSW n       Store Stack Word n
		case 0x3F: printf("store %.8s.word%d",module_name(mem[IP]),mem[IP+1]); IP+=2; break; // SEW n m        Store External Word

		case 0x40: IP = extended_opcode(IP); break; // EXT1_OPCODE op
		case 0x41: printf("load stack dword0"); break; // LSD0        Load Stack Double Word #0
		case 0x42: printf("load global word2"); break; // LGW2        Load Global Word #2
		case 0x43: printf("load global word3"); break; // LGW3        Load Global Word #3
		case 0x44: printf("load global word4"); break; // LGW4        Load Global Word #4
		case 0x45: printf("load global word5"); break; // LGW5        Load Global Word #5
		case 0x46: printf("load global word6"); break; // LGW6        Load Global Word #6
		case 0x47: printf("load global word7"); break; // LGW7        Load Global Word #7
		case 0x48: printf("load global word8"); break; // LGW8        Load Global Word #8
		case 0x49: printf("load global word9"); break; // LGW9        Load Global Word #9
		case 0x4A: printf("load global word10"); break; // LGW10       Load Global Word #10
		case 0x4B: printf("load global word11"); break; // LGW11       Load Global Word #11
		case 0x4C: printf("load global word12"); break; // LGW12       Load Global Word #12
		case 0x4D: printf("load global word13"); break; // LGW13       Load Global Word #13
		case 0x4E: printf("load global word14"); break; // LGW14       Load Global Word #14
		case 0x4F: printf("load global word15"); break; // LGW15       Load Global Word #15

		case 0x50: printf("end_program"); break; // Coroutine Transfer from [030a] to [0308]
		case 0x51: printf("store stack dword0"); break; // SSD0        Store Stack Double Word #0
		case 0x52: printf("store global word2"); break; // SGW2		Store Global Word #2
		case 0x53: printf("store global word3"); break; // SGW3		Store Global Word #3
		case 0x54: printf("store global word4"); break; // SGW4		Store Global Word #4
		case 0x55: printf("store global word5"); break; // SGW5		Store Global Word #5
		case 0x56: printf("store global word6"); break; // SGW6		Store Global Word #6
		case 0x57: printf("store global word7"); break; // SGW7		Store Global Word #7
		case 0x58: printf("store global word8"); break; // SGW8		Store Global Word #8
		case 0x59: printf("store global word9"); break; // SGW9		Store Global Word #9
		case 0x5A: printf("store global word10"); break; // SGW10		Store Global Word #10
		case 0x5B: printf("store global word11"); break; // SGW11		Store Global Word #11
		case 0x5C: printf("store global word12"); break; // SGW12		Store Global Word #12
		case 0x5D: printf("store global word13"); break; // SGW13		Store Global Word #13
		case 0x5E: printf("store global word14"); break; // SGW14		Store Global Word #14
		case 0x5F: printf("store global word15"); break; // SGW15		Store Global Word #15

		case 0x60: printf("load stack word0"); break; // LSW0		Load Stack addressed Word #0
		case 0x61: printf("load stack word1"); break; // LSW1		Load Stack addressed Word #1
		case 0x62: printf("load stack word2"); break; // LSW2		Load Stack addressed Word #2
		case 0x63: printf("load stack word3"); break; // LSW3		Load Stack addressed Word #3
		case 0x64: printf("load stack word4"); break; // LSW4		Load Stack addressed Word #4
		case 0x65: printf("load stack word5"); break; // LSW5 		Load Stack addressed Word #5 
		case 0x66: printf("load stack word6"); break; // LSW6 		Load Stack addressed Word #6 
		case 0x67: printf("load stack word7"); break; // LSW7 		Load Stack addressed Word #7 
		case 0x68: printf("load stack word8"); break; // LSW8 		Load Stack addressed Word #8 
		case 0x69: printf("load stack word9"); break; // LSW9  	    Load Stack addressed Word #9 
		case 0x6A: printf("load stack word10"); break; // LSW10		Load Stack addressed Word #10
		case 0x6B: printf("load stack word11"); break; // LSW11		Load Stack addressed Word #11
		case 0x6C: printf("load stack word12"); break; // LSW12		Load Stack addressed Word #12
		case 0x6D: printf("load stack word13"); break; // LSW13		Load Stack addressed Word #13
		case 0x6E: printf("load stack word14"); break; // LSW14		Load Stack addressed Word #14
		case 0x6F: printf("load stack word15"); break; // LSW15		Load Stack addressed Word #15

		case 0x70: printf("store stack word0"); break; // SSW0		Store Stack addressed Word #0
		case 0x71: printf("store stack word1"); break; // SSW1		Store Stack addressed Word #1
		case 0x72: printf("store stack word2"); break; // SSW2		Store Stack addressed Word #2
		case 0x73: printf("store stack word3"); break; // SSW3		Store Stack addressed Word #3
		case 0x74: printf("store stack word4"); break; // SSW4		Store Stack addressed Word #4
		case 0x75: printf("store stack word5"); break; // SSW5 		Store Stack addressed Word #5 
		case 0x76: printf("store stack word6"); break; // SSW6 		Store Stack addressed Word #6 
		case 0x77: printf("store stack word7"); break; // SSW7 		Store Stack addressed Word #7 
		case 0x78: printf("store stack word8"); break; // SSW8 		Store Stack addressed Word #8 
		case 0x79: printf("store stack word9"); break; // SSW9 		Store Stack addressed Word #9 
		case 0x7A: printf("store stack word10"); break; // SSW10		Store Stack addressed Word #10
		case 0x7B: printf("store stack word11"); break; // SSW11		Store Stack addressed Word #11
		case 0x7C: printf("store stack word12"); break; // SSW12		Store Stack addressed Word #12
		case 0x7D: printf("store stack word13"); break; // SSW13		Store Stack addressed Word #13
		case 0x7E: printf("store stack word14"); break; // SSW14		Store Stack addressed Word #14
		case 0x7F: printf("store stack word15"); break; // SSW15		Store Stack addressed Word #15

		case 0x80: printf("load local address %+d",(int8_t)mem[IP++]); break; // LLA n       Load Local Address (Local +/- 2n)
		case 0x81: printf("load global address %d",mem[IP++]); break; // LGA n       Load Global Address (Global + 2n)
		case 0x82: printf("load stack address %d",mem[IP++]); break; // LSA n       Load Stack Address (Pop + 2n)
		case 0x83: printf("load address %.8s.WORD%d",module_name(mem[IP]),mem[IP+1]); IP+=2; break; // LEA n m         Load External Address
		case 0x84: printf("leave %d",mem[IP++]); break; // PROC_LEAVE n
		case 0x85: printf("fct_leave %d",mem[IP++]); break; // FCT_LEAVE n
		case 0x86: printf("longfct_leave %d",mem[IP++]); break; // LONG_FCT_LEAVE n
		case 0x87: printf("asmcode %d",mem[IP++]); break; // ASMCODE n
//                   while (mem[IP]!=0xFF) IP++;
//                   break;
		case 0x88: printf("leave0"); break; // LEAVE0
		case 0x89: printf("leave2"); break; // LEAVE2
		case 0x8A: printf("leave4"); break; // LEAVE4
		case 0x8B: printf("leave6"); break; // LEAVE6
		case 0x8C: call_rel(IP); IP += mem[IP]+1; break; // CALL_REL +n
		case 0x8D: printf("load immediate %d",mem[IP++]); break; // LIB n           Load Immediate Byte 
		case 0x8E: printf("load immediate %d",(int16_t)wmem(IP)); IP+=2; break; // LIW n n         Load Immediate Word
		case 0x8F: printf("load immediate dword %d",dmem(IP)); IP+=4; break; // LID nnmm        Load Immediate Double Word

		case 0x90: printf("load immediate 0"); break; // LI0             Load Immediate 0
		case 0x91: printf("load immediate 1"); break; // LI1
		case 0x92: printf("load immediate 2"); break; // LI2
		case 0x93: printf("load immediate 3"); break; // LI3
		case 0x94: printf("load immediate 4"); break; // LI4
		case 0x95: printf("load immediate 5"); break; // LI5
		case 0x96: printf("load immediate 6"); break; // LI6
		case 0x97: printf("load immediate 7"); break; // LI7
		case 0x98: printf("load immediate 8"); break; // LI8
		case 0x99: printf("load immediate 9"); break; // LI9
		case 0x9A: printf("load immediate 10"); break; // LI10
		case 0x9B: printf("load immediate 11"); break; // LI11
		case 0x9C: printf("load immediate 12"); break; // LI12
		case 0x9D: printf("load immediate 13"); break; // LI13
		case 0x9E: printf("load immediate 14"); break; // LI14
		case 0x9F: printf("load immediate 15"); break; // LI15            Load Immediate 15

		case 0xA0: printf("equal"); break; // EQUAL
		case 0xA1: printf("not_equal"); break; // NOT_EQUAL
		case 0xA2: printf("uless_than"); break; // ULESS_THAN
		case 0xA3: printf("ugreater_than"); break; // UGREATER_THAN
		case 0xA4: printf("uless_or_equal"); break; // ULESS_OR_EQUAL
		case 0xA5: printf("ugreater_or_equal"); break; // UGREATER_OR_EQUAL
		case 0xA6: printf("add"); break; // ADD
		case 0xA7: printf("sub"); break; // SUB
		case 0xA8: printf("umul"); break; // UMUL
		case 0xA9: printf("udiv"); break; // UDIV
		case 0xAA: printf("umod"); break; // UMOD
		case 0xAB: printf("eq0"); break; // EQ0
		case 0xAC: printf("inc"); break; // INC
		case 0xAD: printf("dec"); break; // DEC
		case 0xAE: printf("add %d",mem[IP++]); break; // ADD n
		case 0xAF: printf("sub %d",mem[IP++]); break; // SUB n

		case 0xB0: printf("shl %d",mem[IP++]); break; // SHL n
		case 0xB1: printf("shr %d",mem[IP++]); break; // SHR n
		case 0xB2: printf("iless_than"); break; // ILESS_THAN
		case 0xB3: printf("igreater_than"); break; // IGREATER_THAN
		case 0xB4: printf("iless_or_equal"); break; // ILESS_OR_EQUAL
		case 0xB5: printf("igreater_or_equal"); break; // IGREATER_OR_EQUAL
		case 0xB6: printf("not"); break; // NOT
		case 0xB7: printf("complement"); break; // COMPLEMENT
		case 0xB8: printf("imul"); break; // IMUL
		case 0xB9: printf("idiv"); break; // IDIV
		case 0xBA: printf("long_to_card"); break; // LONG_TO_CARD
		case 0xBB: printf("long_to_int"); break; // LONG_TO_INT
		case 0xBC: printf("abs"); break; // ABS
		case 0xBD: printf("int_to_long"); break; // INT_TO_LONG
		case 0xBE: printf("long_to_float"); break; // LONG_TO_FLOAT
		case 0xBF: printf("float_to_long"); break; // FLOAT_TO_LONG

		case 0xC0: printf("uadd_checked"); break; // UADD_CHECK_OVF
		case 0xC1: printf("usub_checked"); break; // USUB_CHECK_OVF
		case 0xC2: printf("umul_checked"); break; // UMUL_CHECK_OVF
		case 0xC3: printf("system"); break; // SYSTEM (BDOS)
		case 0xC4: printf("string_comp"); break; // STRING_COMPARE
		case 0xC5: printf("dcompare"); break; // DCOMPARE
		case 0xC6: printf("dadd"); break; // DADD
		case 0xC7: printf("dsub"); break; // DSUB
		case 0xC8: printf("dmul"); break; // DMUL
		case 0xC9: printf("ddiv"); break; // DDIV
		case 0xCA: printf("dmod"); break; // DMOD
		case 0xCB: printf("not_zero"); break; // NOT_ZERO
		case 0xCC: printf("dabs"); break; // DABS
		case 0xCD: { // SWITCH
                       int low_bound = mem[IP++]+256*mem[IP++] - 32678;
                       int hi_bound = low_bound + mem[IP++]+256*mem[IP++];
                       int16_t relative_ret = mem[IP++]+256*mem[IP++];
                       int return_addr = relative_ret + IP - 1;
                       if (mem[IP+1]&0x80) 
                           printf("callswitch (return to %04x)",return_addr);
                       else
                           printf("jumpswitch");
                       if (hi_bound-low_bound <= 256)
                       for (int i=low_bound; i<=hi_bound; i++) {
                           int16_t relative_addr = mem[IP++]+256*mem[IP++];
                           int target = relative_addr + IP - 1;
                           printf("\n\tcase %d => %04x",i,target);
                       }
                       break;
                   }
		case 0xCE: printf("jump_stack"); break; // JUMP_STACK
		case 0xCF: printf("push_code_addr %04x",(IP+1+mem[IP]+256*mem[IP+1])&0xffff); IP+=2; break; // PUSH PC+nn

		case 0xD0: printf("iadd_checked"); break; // IADD_CHECK_OVF
		case 0xD1: printf("isub_checked"); break; // ISUB_CHECK_OVF
		case 0xD2: printf("reserve"); break; // STACK_RESERVE
		case 0xD3: printf("string_reserve"); break; // RESERVE STRING
		case 0xD4: printf("enter %+d",(int8_t)mem[IP++]); break; // ENTER n
		case 0xD5: printf("real_compare"); break; // REAL_COMPARE
		case 0xD6: printf("real_add"); break; // REAL_ADD
		case 0xD7: printf("real_sub"); break; // REAL_SUB
		case 0xD8: printf("real_mul"); break; // REAL_MUL
		case 0xD9: printf("real_div"); break; // REAL_DIV
		case 0xDA: printf("urange_check"); break; // URANGE_CHECK
		case 0xDB: printf("irange_check"); break; // IRANGE_CHECK
		case 0xDC: printf("limit_check"); break; // LIMIT_CHECK
		case 0xDD: printf("check_positive"); break; // CHECK_POSITIVE
		case 0xDE: printf("andjp %04x",mem[IP++]+IP); break; // ANDJP +n            short circuit AND
		case 0xDF: printf("orjp %04x",mem[IP++]+IP); break; // ORJP +n             short circuit OR

		case 0xE0: printf("jp %04x",(IP+1+mem[IP]+256*mem[IP+1])&0xffff); IP+=2; break; // JP nn               Jump
		case 0xE1: printf("jpfalse %04x",(IP+1+mem[IP]+256*mem[IP+1])&0xffff); IP+=2; break; // JPC nn               Jump
		case 0xE2: printf("jp %04x",mem[IP++]+IP); break; // JPF +n              Jump Forward
		case 0xE3: printf("jpfalse %04x",mem[IP++]+IP); break; // JPFC +n             Jump Forward Conditional
		case 0xE4: printf("jp %04x",-mem[IP++]+IP); break; // JPB -n              Jump Backward
		case 0xE5: printf("jpfalse %04x",-mem[IP++]+IP); break; // JPBC -n             Jump Backward Conditional
		case 0xE6: printf("bitwise_or"); break; // BITWISE_OR
		case 0xE7: printf("bitwise_in"); break; // BITWISE_IN
		case 0xE8: printf("bitwise_and"); break; // BITWISE_AND
		case 0xE9: printf("bitwise_xor"); break; // BITWISE_XOR
		case 0xEA: printf("power2"); break; // POWER2
		case 0xEB: printf("extern_proc_call"); break; // EXTERN_PROC_CALL  (module address and proc number on stack)
		case 0xEC: printf("nested_call proc%d",mem[IP++]); break; // NESTED_PROC_CALL n
		case 0xED: printf("call proc%d",mem[IP++]); break; // PROC_CALL n
		case 0xEE: printf("call_with_frame proc%d",mem[IP++]); break; // PROC_CALL_WITH_FRAME n
		case 0xEF: printf("call %.8s.%s",module_name(mem[IP]),proc_name(module_name(mem[IP]),mem[IP+1])); IP+=2; break; // EXTERN_PROC_CALL m n

		case 0xF0: printf("call %.8s.%s",module_name(mem[IP]/16),proc_name(module_name(mem[IP]/16),mem[IP]%16)); IP++; break; // EXTERN_PROC_CALL mn  (m module number (high nibble))
		case 0xF1: printf("call proc1"); break; // PROC_CALL1
		case 0xF2: printf("call proc2"); break; // PROC_CALL2
		case 0xF3: printf("call proc3"); break; // PROC_CALL3
		case 0xF4: printf("call proc4"); break; // PROC_CALL4
		case 0xF5: printf("call proc5"); break; // PROC_CALL5
		case 0xF6: printf("call proc6"); break; // PROC_CALL6
		case 0xF7: printf("call proc7"); break; // PROC_CALL7
		case 0xF8: printf("call proc8"); break; // PROC_CALL8
		case 0xF9: printf("call proc9"); break; // PROC_CALL9
		case 0xFA: printf("call proc10"); break; // PROC_CALL10
		case 0xFB: printf("call proc11"); break; // PROC_CALL11
		case 0xFC: printf("call proc12"); break; // PROC_CALL12
		case 0xFD: printf("call proc13"); break; // PROC_CALL13
		case 0xFE: printf("call proc14"); break; // PROC_CALL14
		case 0xFF: if (mem[IP]==0xD4 || mem[IP]==0x87) break;
                   printf("call proc15"); // PROC_CALL15
                   break;
        }
        printf("\n");
    }
}

uint16_t proc_table_addr(int base) { return wmem(base-2); }

void module(int base, int dependencies)
{
    int depend_num = 0;
    uint16_t *module_table = (uint16_t *)(mem+base-18);
    int16_t *proc_table = (int16_t *)(mem+proc_table_addr(base));
//    for (int num=0; module_table-num != proc_table ; num++)
//        module(module_table[-num]);

    current_base = base;
    char *name = (char *)(mem+base-14);
    printf("%04x : Module %.8s\n", base, name);
//    printf("\tDependency table at %d\n",base-18);
//    printf("\tProcedure table at %d\n",proc_table_addr(base));
    for (int num=0; num<dependencies; num++)
        printf("\tdepends on %.8s \n",module_name(num));
    printf("\n");

    uint16_t min=0xFFFF, max = proc_table_addr(base);
    for(int procnum=0; proc_table[-procnum]<0; procnum++) {
        uint16_t proc_addr = proc_table_addr(base)-2*procnum+1 
                           + proc_table[-procnum];
        if (mem[proc_addr-1] >= 0x80)
            printf("%.8s.proc%d: %04x\n",name,procnum, proc_addr);
        else {
            printf("%.8s.",name);
            decode38(proc_addr-6);
            decode38(proc_addr-4);
            printf(": %04x\n", proc_addr);
        }
        if (proc_addr < min) min = proc_addr;
    }
    printf("\n\n");
    unassemble(min, max);
    printf("\n\n\n");
}

void unassemble_m2(void)
{
    FILE *fd = fopen("M2.COM","r");
    fread(mem+0x0100,65536,1,fd);
    fclose(fd);

    module(0x21D2,0); // KERNEL
    //procedure(0x1f12);
    printf("\n\n\n");

    module(0x258B,6); // COMLINE
    module(0x326C,4); // EDITOR
    module(0x32D4,7); // COMPILER
    module(0x333A,7); // SYMTAB
    module(0x3386,2); // DOUBLES
    module(0x35FD,0); // TERMINAL
    module(0x3FBF,1); // LOADER
    module(0x3FFD,4); // CODEGEN
    module(0x4045,10);// ERRORS
    module(0x406F,5); // EDIT2
    module(0x4772,3); // TEXTS
    module(0x51C0,0); // FILES
    module(0x5D18,0); // CONVERT
    module(0x5D2E,1); // EXEC
    module(0x5D54,9); // SCANNER
    module(0x5DAC,5); // EDITDISK
}


void unassemble_comp(void)
{
    FILE *fd = fopen("COMPILE.MCD","r");
    fread(mem,65536,1,fd);
    fclose(fd);
    unassemble(0x0EA3,0x0F00);
}

struct {
    short file_size; // not counting header
    short module_start; // actually 80 bytes before module_start
    short code_size; // => gives addr of module dependencies
    short nb_dependencies;
    short reserved[4];
} header;

void unassemble_mcd(char *filename)
{
    unsigned short version, location;
    int num_dependency;
    char name[9]="12345678";
    FILE *fd = fopen(filename,"r");
    fread(&header,1,sizeof(header),fd);
    fread(mem,header.code_size,1,fd);
    for (int i=header.nb_dependencies-1; i>=0; i--) {
        fread(name, 8, 1, fd);
        fread(&version,  1, sizeof(short), fd);
        fread(&location, 1, sizeof(short), fd);
        num_dependency = (header.module_start+62-location)/2;
        strcpy(depend_names[num_dependency],name);
    }
    fclose(fd);
    printf("module start at %04x\n",header.module_start+80);
    module(header.module_start+80, header.nb_dependencies);
}

void main(int argc, char *argv[])
{
    if (argc > 1) unassemble_mcd(argv[1]);
    else unassemble_m2();
}

