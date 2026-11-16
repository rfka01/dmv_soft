program DMVTrak;
{ DMVTRAK - MOD-Player und Tracker fuer den Lautsprecher der NCR DMV
  Turbo Pascal 3.01A, Compiler-Option C (COM-Datei).
  Klang ueber den Tastatur-Controller 8741: mit der Firmware EXTKB
  (Befehl 05h) drei Stimmen und Rauschen, sonst eine Stimme (Befehl 06h);
  oder ueber ein Covox Speech Thing an der K210 (/C).
  Code: Claude (Anthropic), Idee und Prompts: rfka01 - Lizenz MIT }

{$C-}
{$R-}
{$V-}

const
  Version  = '0.6';
  MaxPat   = 100;               { Patterns 0..99 }
  MaxCh    = 8;                 { Kanaele }
  NIns     = 31;                { Instrumente 1..31 }
  Rows     = 64;                { Zeilen je Pattern }
  ScrRows  = 24;                { Bildschirmzeilen 0..23 }
  PageRows = 16;                { sichtbare Patternzeilen }
  Top      = 3;                 { erste Patternzeile am Bildschirm }
  MaxLen   = 50;                { laengster Einzelton in 20-ms-Einheiten }
  QSize    = 32;                { Tonwarteschlange }
  Unit8741 = 2048;
  SmpMax   = 65000.0;           { laengstes Sample im Speicher (Covox) }              { 20,48 ms in 1/100 ms }

type
  Str80   = string[80];
  Str20   = string[20];
  PatBuf  = array[0..2047] of byte;   { 64 Zeilen x 8 Kanaele x 4 Byte }
  PatPtr  = ^PatBuf;
  SmpArr  = array[0..32766] of byte;   { Index ueber 32767 als negative Zahl ($R-) }
  SmpPtr  = ^SmpArr;
  FarPtr  = record O, S: integer; end;
  RegPack = record
              AX, BX, CX, DX, BP, SI, DI, DS, ES, Flags: integer;
            end;

var
  { Lied }
  Title    : Str20;
  NChan    : integer;
  SongLen  : integer;
  Restart  : integer;
  NPat     : integer;
  Order    : array[0..127] of byte;
  Pat      : array[0..99] of PatPtr;
  IName    : array[1..31] of string[22];
  IPrio    : array[1..31] of integer;    { 0 = stumm, 1..9 }
  ITrans   : array[1..31] of integer;    { Halbtoene }
  IVol     : array[1..31] of integer;    { 0..64 }
  IHold    : array[1..31] of boolean;    { Ton haelt (Schleife) }
  ILen     : array[1..31] of real;       { Samplelaenge in Byte }
  INoise   : array[1..31] of boolean;    { Schlagzeug: Rauschen (Synthesizer) }
  ArpMode  : boolean;                    { false = fuehrende Stimme }
  GTrans   : integer;                    { globale Transponierung }
  InitSpd  : integer;
  InitBPM  : integer;
  Looping  : boolean;
  FileName : Str80;                     { Name zum Speichern (DTK) }
  SrcName  : Str80;                     { geladene Datei }
  SrcFmt   : Str20;                     { ihr Format, z. B. 'MOD M.K.' }
  Modified : boolean;
  { Covox (DTKCOV) }
  CovWant, CovMode, CovIrq : boolean;
  CovRate, CovDiv          : integer;
  CovSeg                   : integer;
  CovBlk                   : ^byte;
  CovEntry                 : FarPtr;
  CovKH, CovKL             : integer;    { 3546894,6 * 65536 / Rate }
  CovAcc                   : integer;
  CovNoK210                : boolean;
  ISmp     : array[1..31] of SmpPtr;     { Sampledaten (nil = keine) }
  ISz      : array[1..31] of integer;    { belegte Groesse }
  ISLen    : array[1..31] of integer;    { Laenge in Byte }
  ILpS, ILpL : array[1..31] of integer;  { Schleife in Byte }
  CLast    : array[0..7] of integer;     { zuletzt gesehener Anschlag }
  CSOff    : array[0..7] of integer;     { Sample-Offset (Effekt 9) }
  SmpLoaded, SmpTotal : integer;


{$I DTKSND.INC}
{$I DTKSCR.INC}
{$I DTKSONG.INC}
{$I DTKPLAY.INC}
{$I DTKSYN.INC}
{$I DTKFILE.INC}
{$I COVBIN.INC}
{$I DTKCOV.INC}
{$I DTKEDIT.INC}

procedure Help;
begin
  WriteLn('DMVTRAK ', Version, ' - MOD-Player und Tracker fuer die NCR DMV');
  WriteLn('Aufruf:  DMVTRAK [datei] [/P | /C[:rate]]');
  WriteLn('  datei       MOD (15/31 Instrumente, 4/6/8 Kanaele) oder DTK');
  WriteLn('  ohne /P /C  Editor');
  WriteLn('  /P          nur abspielen ueber den Tastatur-Controller (8741);');
  WriteLn('              3 Stimmen mit Firmware EXTKB, sonst 1 Stimme');
  WriteLn('  /C          nur abspielen ueber das Covox an der K210 (Port 60h),');
  WriteLn('              nur MODs mit Samples; /C:4000 = 4000 Hz (2000..6400, sonst 5000)');
  WriteLn('  /?          diese Hilfe');
  WriteLn;
  WriteLn('Abspielen:  Leertaste Pause/weiter   RETURN von vorn   S Stopp');
  WriteLn('            Pfeil links/rechts (auch ^S ^D) 10 s zurueck/vor   ESC/Q Ende');
  WriteLn('            nur /C: + - Abtastrate um 500 Hz hoeher/tiefer');
  WriteLn;
  WriteLn('Editor:     Pfeile Zelle   ^R ^C 16 Zeilen   TAB Kanal   < > Position');
  WriteLn('            + - Oktave   Leertaste Spielen/Stopp   RETURN Lied von vorn');
  WriteLn('            Noten  Y S X D C V G B H N J M ,      (C bis C)');
  WriteLn('                   Q 2 W 3 E R 5 T 6 Z 7 U I 9 O 0 P   (eine Oktave hoeher)');
  WriteLn('            1 Ton aus   . oder DEL loeschen   0-9 A-F Instrument/Effekt');
  WriteLn('            ESC Menue: L Laden  S Speichern  N Neu  I Instrumente');
  WriteLn('              R Reihenfolge  M Klang  T Tempo  W Wiederholen  U Titel');
  WriteLn('              G Transponieren  E Ende');
  WriteLn;
  WriteLn('Mehr in DMVTRAK.TXT.');
end;

var
  P1, P2 : Str80;
  I      : integer;
  PlayOnly : boolean;

begin
  for I := 0 to MaxPat - 1 do Pat[I] := nil;
  CovSmpInit;
  CovWant := false; CovMode := false; CovRate := 5000;
  EditActive := false;
  KbdInit;
  SndInit;
  SynInit;
  NewSong;
  PlayOnly := false;
  P1 := '';
  SrcName := ''; SrcFmt := '';
  for I := 1 to ParamCount do
  begin
    P2 := ParamStr(I);
    if (P2 = '/?') or (P2 = '-?') or (P2 = '/h') or (P2 = '/H') then
    begin
      Help;
      Halt;
    end;
    if (Length(P2) = 2) and (P2[1] = '/') and (UpCase(P2[2]) = 'P') then
      PlayOnly := true
    else if (Length(P2) >= 2) and (P2[1] = '/') and (UpCase(P2[2]) = 'C') then
    begin
      PlayOnly := true; CovWant := true;
      if (Length(P2) > 3) and (P2[3] = ':') then
      begin
        Val(Copy(P2, 4, 5), CovRate, I);
        if I <> 0 then CovRate := 5000;
        if CovRate < 2000 then CovRate := 2000;
        if CovRate > 6400 then CovRate := 6400;
      end;
    end
    else
      P1 := P2;
  end;
  if CovWant then
  begin
    if not CovFindK210 then
    begin
      WriteLn('DMVTRAK: Keine K210 (8255 auf IFSEL 0A, Port 60h) gefunden.');
      WriteLn('Das Covox Speech Thing muss am Druckerausgang der K210 stecken.');
      Halt;
    end;
    if not CovAlloc then begin WriteLn('DMVTRAK: Kein Speicher.'); Halt; end;
    if P1 = '' then begin WriteLn('DMVTRAK: /C braucht eine Datei.'); Halt; end;
    WriteLn('Lade ', P1, ' ...');
  end;
  if P1 <> '' then
    if not LoadAny(P1) then
    begin
      WriteLn('DMVTRAK: ', LastErr);
      if PlayOnly then Halt;
      NewSong;
    end;
  if CovWant then
    if (SrcFmt = 'DTK') or (SmpLoaded = 0) then
    begin
      WriteLn('DMVTRAK: ', SrcName, ' enthaelt keine Samples.');
      WriteLn('Die Wiedergabe ueber das Covox (/C) braucht ein MOD mit Samples.');
      Halt;
    end;
  if PlayOnly then
    PlayerMode
  else
    Editor;
  if SynOn then SynStop;
  SndIdle;
end.
