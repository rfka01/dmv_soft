{ DTKCOV.INC - Wiedergabe ueber das Covox Speech Thing an der K210

  Das Covox ist ein 8-Bit-DAC an den Datenleitungen des Druckerausgangs.
  Die K210 (8255 auf IFSEL 0A, Port 60h-63h) gibt jedes Byte an Port A
  sofort aus. Den Takt liefert der 8253 (Kanal 2, 500 kHz): Er wird fuer
  die Wiedergabe auf die Abtastrate gestellt; jeder Interrupt (IRQ0,
  INT 08h, braucht die K235 mit 8259) holt ein Byte aus einem Ringpuffer.
  Der alte Handler wird im alten Takt weiter aufgerufen, die DOS-Uhr
  laeuft also richtig. Gemischt wird pro Tick im Vordergrund (COVMIX.ASM,
  als Bytes in COVBIN.INC). Nur echte Samples aus dem MOD; Instrumente
  ohne Sampledaten bleiben stumm. }



const
  CovBlkLen = $2400;            { Ring 4 KB, Variablen, Kanaele, Code, Tabellen }
  CovCodeOfs = $10B0;
  CRD = $1000; CWR = $1002; CTACC = $1004; COLDDIV = $1006; CNEWDIV = $1008;
  COLDVEC = $100A; CICOUNT = $100E; CUNDER = $1010; CNSAMP = $1014; CNCH = $1016;
  CCHAN = $1020; CVOLTAB = $1300;

var
  CovFirst : boolean;
  CPLast, CVLast : array[0..7] of integer;   { zuletzt geschrieben }

procedure CovFarCall(var E: FarPtr);
begin
  Inline(
    $55/                    {  push bp               }
    $1E/                    {  push ds               }
    $C4/$7E/<E/             {  les  di,[bp+E]        }
    $26/$FF/$1D/            {  call far es:[di]      }
    $1F/                    {  pop  ds               }
    $5D);                   {  pop  bp               }
end;

function CovFindK210: boolean;  { 8255 auf IFSEL 0A wie im Startbildschirm }
var I, A: integer;
begin
  A := $FF;
  for I := 0 to 3 do A := A and Port[$60 + I];
  CovFindK210 := (A <> $FF) and ((Port[$63] and $80) <> 0);
end;

function CovAlloc: boolean;     { Block fuer Ring, Code und Tabellen }
begin
  CovAlloc := false;
  if (MaxAvail >= 0) and (MaxAvail < CovBlkLen div 16 + 4) then exit;
  GetMem(CovBlk, CovBlkLen + 16);
  CovSeg := Seg(CovBlk^) + (Ofs(CovBlk^) + 15) div 16;
  CovAlloc := true;
end;

function Pit2Max: integer;      { groesster Zaehlerstand von Kanal 2 }
var I, V, M: integer;
begin
  M := 0;
  for I := 1 to 3000 do
  begin
    Port[$83] := $80;           { Kanal 2 festhalten }
    V := Port[$82];
    V := V + Port[$82] shl 8;
    if V > M then M := V;
  end;
  Pit2Max := M;
end;

function CovStart;              { forward in DTKPLAY; Zeitgeber und Interrupt umstellen }
var I, J, V, D, Old: integer;
    K: real;
begin
  CovStart := false;
  FillChar(Mem[CovSeg:0], CovBlkLen, 0);
  for I := 0 to CovCodeLen - 1 do Mem[CovSeg:CovCodeOfs + I] := CovCode[I];
  if NChan <= 4 then D := 64 else D := 128;     { 16 * 4 bzw. 16 * 8 }
  for V := 0 to 16 do
    for J := 0 to 255 do
    begin
      if J < 128 then I := J else I := J - 256;
      Mem[CovSeg:CVOLTAB + V * 256 + J] := (I * V div D) and $FF;
    end;
  for I := 0 to $FFF do Mem[CovSeg:I] := $80;
  { Schrittweite: Amiga-Takt 3546894,6 / Periode / Rate, als 16.16 }
  K := 3546894.6 * 65536.0 / CovRate;
  CovKH := Trunc(K / 65536.0);
  CovKL := Real16(K - CovKH * 65536.0);
  CovDiv := Round(500000.0 / CovRate);
  { alter Teiler: 27463 (DOS 3.3/DR-DOS) oder 5000 (NCR) }
  Old := Pit2Max;
  if Abs(Old - 27463) < 1500 then Old := 27463
  else if Abs(Old - 5000) < 300 then Old := 5000
  else if Old < 200 then Old := 27463;
  MemW[CovSeg:COLDDIV] := Old;
  MemW[CovSeg:CNEWDIV] := CovDiv;
  MemW[CovSeg:CTACC] := Old;
  MemW[CovSeg:CNCH] := NChan;
  CovEntry.S := CovSeg; CovEntry.O := CovCodeOfs + 3;
  for I := 0 to 7 do
  begin
    CLast[I] := -1; CSOff[I] := 0; CPLast[I] := -1; CVLast[I] := 0;
  end;
  CovAcc := 0;
  CovFirst := true;
  { 8255: Modus 1, Port A Ausgang; INIT und AUTOFD inaktiv }
  Port[$63] := $A2; Port[$63] := $03; Port[$63] := $05;
  Port[$60] := $80;
  Inline($FA);                  { cli }
  MemW[CovSeg:COLDVEC] := MemW[0:$20];
  MemW[CovSeg:COLDVEC + 2] := MemW[0:$22];
  MemW[0:$20] := CovCodeOfs;
  MemW[0:$22] := CovSeg;
  Port[$83] := $B4;             { Kanal 2, Modus 2 }
  Port[$82] := CovDiv and $FF;
  Port[$82] := CovDiv shr 8;
  Inline($FB);                  { sti }
  I := 0;
  while (MemW[CovSeg:CICOUNT] = 0) and (I < 30000) do I := I + 1;
  CovIrq := MemW[CovSeg:CICOUNT] <> 0;
  CovMode := true;
  CovStart := true;
end;

procedure CovStop;
var Old: integer;
begin
  if not CovMode then exit;
  Old := MemW[CovSeg:COLDDIV];
  Inline($FA);
  Port[$83] := $B6;             { Kanal 2, Modus 3 }
  Port[$82] := Old and $FF;
  Port[$82] := Old shr 8;
  MemW[0:$20] := MemW[CovSeg:COLDVEC];
  MemW[0:$22] := MemW[CovSeg:COLDVEC + 2];
  Inline($FB);
  Port[$60] := $80;
  CovMode := false;
end;

function CovFree;               { freier Platz im Ring }
begin
  CovFree := (MemW[CovSeg:CRD] - MemW[CovSeg:CWR] - 1) and $FFF;
end;

function CovEmpty;
begin
  CovEmpty := MemW[CovSeg:CRD] = MemW[CovSeg:CWR];
end;

function CovTickMax;            { hoechstens so viele Werte je Tick }
begin
  CovTickMax := CovRate div 10 + 2;     { 2,5 s / BPM, BPM >= 32 -> <= Rate/12,8 }
end;

{ Schrittweite fuer Periode P }
procedure CovStep(P: integer; var SI, SF: integer);
var R: integer;
begin
  if P < 56 then P := 56;
  SI := CovKH div P;
  R := CovKH mod P;
  UDiv(R, CovKL, P, SF);
end;

procedure CovTick;              { Kanaele stellen, einen Tick mischen }
var C, I, B, N, P, A, SI, SF, V: integer;
begin
  for C := 0 to NChan - 1 do
  begin
    B := CCHAN + C * 16;
    I := CIns[C];
    if (I < 1) or (I > NIns) then I := 0
    else if ISmp[I] = nil then I := 0;
    if (I > 0) and (CTrig[C] <> CLast[C]) then
    begin
      CLast[C] := CTrig[C];
      P := CSOff[C];
      if not ULess(P, ISLen[I]) then P := 0;
      MemW[CovSeg:B + 2] := Ofs(ISmp[I]^) + P;
      MemW[CovSeg:B + 4] := 0;
      if ILpL[I] > 0 then
      begin
        MemW[CovSeg:B + 10] := Ofs(ISmp[I]^) + ILpS[I] + ILpL[I];
        MemW[CovSeg:B + 12] := ILpL[I];
      end
      else
      begin
        MemW[CovSeg:B + 10] := Ofs(ISmp[I]^) + ISLen[I];
        MemW[CovSeg:B + 12] := 0;
      end;
      MemW[CovSeg:B] := Seg(ISmp[I]^);
    end;
    V := 0;
    if I > 0 then
    begin
      P := CPer[C];
      if P > 0 then
      begin
        A := CPar[C];
        if (CEff[C] = 0) and (A > 0) then
        begin
          N := NoteOfPer(P);
          case PlTick mod 3 of
            1: N := N + A shr 4;
            2: N := N + A and 15;
          end;
          if N > 60 then N := 60;
          P := PerTab[N];
        end;
        if P <> CPLast[C] then          { Schritt nur bei neuer Tonhoehe }
        begin
          CPLast[C] := P;
          CovStep(P, SI, SF);
          MemW[CovSeg:B + 6] := SI;
          MemW[CovSeg:B + 8] := SF;
        end;
        if IPrio[I] > 0 then V := CVol[C] shr 2;
      end;
    end;
    if V <> CVLast[C] then
    begin
      CVLast[C] := V;
      Mem[CovSeg:B + 14] := V;
    end;
  end;
  { Werte je Tick: Rate * 2,5 / BPM, Rest mitnehmen }
  CovAcc := CovAcc + CovRate * 5;
  N := CovAcc div (2 * BPM);
  CovAcc := CovAcc mod (2 * BPM);
  if N > 1024 then N := 1024;
  MemW[CovSeg:CNSAMP] := N;
  CovFarCall(CovEntry);
  if CovFirst then
  begin
    MemW[CovSeg:CUNDER] := 0;  { Aussetzer erst ab dem ersten Tick zaehlen }
    CovFirst := false;
  end;
end;

procedure CovSetRate(R: integer);   { Rate waehrend der Wiedergabe aendern }
var K: real;
    I: integer;
begin
  if R < 2000 then R := 2000;
  if R > 6400 then R := 6400;
  CovRate := R;
  K := 3546894.6 * 65536.0 / CovRate;
  CovKH := Trunc(K / 65536.0);
  CovKL := Real16(K - CovKH * 65536.0);
  CovDiv := Round(500000.0 / CovRate);
  CovAcc := 0;
  for I := 0 to 7 do CPLast[I] := -1;
  Inline($FA);
  MemW[CovSeg:CNEWDIV] := CovDiv;
  Port[$83] := $B4;
  Port[$82] := CovDiv and $FF;
  Port[$82] := CovDiv shr 8;
  MemW[CovSeg:CUNDER] := 0;     { Aussetzer fuer die neue Rate neu zaehlen }
  Inline($FB);
end;
