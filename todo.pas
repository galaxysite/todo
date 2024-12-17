program wtdgc;

{$MODE OBJFPC}
{$H+}
{$RANGECHECKS ON}
{$SMARTLINK ON}

{
    ToDo for GNU/Linux.
    Reworked on FreePascal based on CP/M todo https://github.com/MiguelVis/RetroProjects.git
    Format description: https://github.com/todotxt/todo.txt

    Written on FreePascal (https://freepascal.org/).
    Copyright (C) 2024  Artyomov Alexander
    http://self-made-free.ru/
    aralni@mail.ru

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
}

uses
 SysUtils;

type

 TMonth = 1..12;
 TDay = 1..31;
 TPrio = 'A'..'Z';

 TTask = packed object
  Y : Int64;
  M : TMonth;
  D : TDay;
  InputedDate : utf8string; // for filter
  Subj : utf8string;
  Prio : TPrio;
  PrioExists : bytebool;
  Done : bytebool;
 public
  function ExportString : utf8string;
  function TableString : utf8string;
  function ImportString(s : utf8string) : bytebool;
  function AskTask(doneflag, newflag : bytebool) : bytebool;
  function TryAddDone(s : utf8string) : bytebool;
  function TryAddPrio(s : utf8string) : bytebool;
  function TryAddDate(s : utf8string) : bytebool;
 end;

 TTasks = packed object
 a : array of TTask;
 filter : boolean;
 ft : TTask;
 saved : bytebool;
 public
  procedure Intro;
  procedure TableHeader;
  procedure TableFooter;
  procedure DoHelp;
  procedure Menu;
  procedure Add(t : TTask);
  procedure ReadFile;
  function SaveFile : bytebool;
  procedure DoAddTask;
  procedure DoAddTaskEx(s : utf8string);
  procedure DoPrint;
  procedure DoPrintEx(i : Int64);
  procedure DoSave;
  procedure DoPack;
  procedure DoKillTaskEx(i : Int64);
  procedure DoChgTaskEx(i : Int64);
  procedure DoDoneTaskEx(i : Int64);
  procedure DoPendTaskEx(i : Int64);
  procedure DoSortEx(s : utf8string);
  function Comp(i, j : Int64; t : char) : bytebool;
  procedure Sort(c : char);
  procedure Swap(i, j : Int64);
  procedure DoFilter;
  procedure DoFilterEx(s : utf8string);
  function ChkFilter(i : Int64) : bytebool;
  function AreYouSure(s : utf8string) : bytebool;
  function DoQuit : bytebool;
 end;

var
 fn_todo : utf8string = 'todo.txt';
 fpi : Text;
 ts : TTasks;

function inttofix2str(i : Int64) : utf8string;
begin result := inttostr(i);if 10 > i then result := '0' + result; end;

function isDigit(c : utf8char) : bytebool;
begin
Exit(c in ['0'..'9']);
end;

function TTasks.AreYouSure(s : utf8string) : bytebool;
var
 tmp : utf8string;
begin
Write(s); WriteLn('. Are you sure (Y/N)? ');
ReadLn(tmp); WriteLn;WriteLn;
if Length(tmp) < 1 then Exit(false);
if (tmp[1] = 'Y') or (tmp[1] = 'y') then Exit(true) else Exit(false);
end;

procedure TTasks.DoDoneTaskEx(i : Int64);
var
 h : Int64;
begin
h := High(a);
if (i > h) or (i < 0) then Exit;
a[i].Done := true;
saved := false;
end;

procedure TTasks.DoPendTaskEx(i : Int64);
var
 h : Int64;
begin
h := High(a);
if (i > h) or (i < 0) then Exit;
a[i].Done := false;
saved := false;
end;

procedure TTasks.DoAddTask;
var
 t : TTask;
begin
if t.AskTask(false,true) then begin
 WriteLn('Bad user input. Not added.');
end else begin
 Add(t);
 saved := false;
end;
end;

procedure TTasks.DoAddTaskEx(s : utf8string);
var
 t : TTask;
begin
if t.ImportString(s) then begin
 WriteLn('Bad user input. Not added.');
end else begin
 Add(t);
 saved := false;
end;
end;

function ItoStr(i : Int64) : utf8string;
var
 tmp : string;
 s : string[6];
 f : Int64;
begin
s := '      ';
tmp := IntToStr(i) + '.';
for f := 1 to Length(tmp) do
 s[f] := tmp[f];
Exit(s);
end;

procedure TTasks.TableHeader;
var
 s : utf8string;
begin
WriteLn('------+-+---+----------+---------------------');
WriteLn('  No  |D| P |   Date   |    Subject');
if filter then begin
 if ft.Done then s := 'x|' else s := ' |';
 if ft.PrioExists then s := s + '(' + ft.Prio + ')|' else s := s + '   |';
 if ft.Y <> 0 then s := s + IntToStr(ft.Y) + '-' + IntToFix2Str(ft.M) + '-' + IntToFix2Str(ft.D) + '|' else s := s + '          |';
 s := s + ft.Subj;
 WriteLn('Filter|' + s);
end;
WriteLn('------+-+---+----------+---------------------');
end;

procedure TTasks.TableFooter;
begin
WriteLn('------+-+---+----------+---------------------');
end;

procedure TTasks.DoPrint;
var
 f : Int64;
begin
TableHeader;
for f := 0 to High(a) do begin
if filter then if ChkFilter(f) then continue;
 WriteLn(ItoStr(f), '|', a[f].TableString);
end;
TableFooter;
end;
procedure TTasks.DoPrintEx(i : Int64);
var
 f : Int64;
begin
TableHeader;
if i = 0 then exit;
for f := 0 to High(a) do begin
if filter then if not ChkFilter(f) then
 WriteLn(ItoStr(f), '|', a[f].TableString);
if f = i-1 then break;
end; {next f}
TableFooter;
end;

function TTask.TryAddDone(s : utf8string) : bytebool;
begin
if s = 'x' then begin Done := true; Exit(false); end;
if s = '' then begin Done := false; Exit(false); end
 else Exit(true);
end;

function TTask.TryAddPrio(s : utf8string) : bytebool;
begin
if s = '' then begin PrioExists := false; Prio := 'A'; Exit(false); end;
if s[1] in ['A'..'Z'] then begin Prio := s[1]; PrioExists := true; Exit(false); end
 else Exit(true);
end;

function TTask.TryAddDate(s : utf8string) : bytebool;
var
 tm, td : Int64;
begin
InputedDate := s;
if Length(s) < 10 then begin Y := 0; Exit(false); end;
if (s[5] = '-') and (s[8] = '-') and
 isDigit(s[1]) and isDigit(s[2]) and
 isDigit(s[3]) and isDigit(s[4]) and
 isDigit(s[6]) and isDigit(s[7]) and
 isDigit(s[9]) and isDigit(s[10]) then begin
Y := StrToIntDef(Copy(s,1,4),0);
if Y = 0 then Exit(true);
tm := StrToIntDef(Copy(s,6,2),0);
if (tm = 0) or (tm > 12) then Exit(true) else M := tm;
td := StrToIntDef(Copy(s,9,2),0);
if (td = 0) or (td > 31) then Exit(true) else D := td;
end else begin Y := 0; Exit(false); end;
Exit(false);
end;

procedure TTasks.DoChgTaskEx(i : Int64);
begin
if (i < 0) or (i > High(a)) then Exit;
a[i].AskTask(false,false);
saved := false;
end;
	
function TTask.AskTask(doneflag, newflag : bytebool) : bytebool;
var
 s : utf8string;
begin
Done := false;
if doneflag then begin
 WriteLn('Done (x/CR)          : ');
 ReadLn(s);
 if TryAddDone(s) then Exit(true);
 WriteLn;
end;
WriteLn('Priority (A:Z/CR)    : ');
 ReadLn(s);
 if TryAddPrio(s) then Exit(true);
 WriteLn;
WriteLn('Date (yyyy-mm-dd/CR) : ');
 ReadLn(s);
 TryAddDate(s);
 WriteLn;
WriteLn('Subject              : ');
 ReadLn(Subj);
 if Subj = '' then Exit(true);
 WriteLn; WriteLn;
Exit(false);
end;

procedure TTasks.Add(t : TTask);
begin
SetLength(a, Length(a) + 1);
a[High(a)] := t;
end;

procedure TTasks.DoKillTaskEx(i : Int64);
var
 f, h : Int64;
begin
h := High(a);
if (i > h) or (i < 0) then Exit;
for f := i to h-1 do begin
a[f] := a[f+1];
end;
SetLength(a, h);
saved := false;
end;

procedure TTasks.DoPack;
var
 f, ff, h, c : Int64;
begin
if AreYouSure('Done tasks will be killed') = FALSE then Exit;
WriteLn('Packing... ');
c := 0;
h := High(a);
for f := 0 to h do
 if a[f].Done then begin
  for ff := f to h-1 do a[ff] := a[ff+1];
  Inc(c);
 end; {end if}
SetLength(a, Length(a)-c);
WriteLn(c, ' tasks killed');
WriteLn;
saved := false;
end;

function TTask.ExportString : utf8string;
begin
if Subj = '' then Exit('');
result := '';
if Done then result := result + 'x ';
if PrioExists then begin
 result := result + '(' + Prio + ') ';
end;
if Y <> 0 then begin
 result := result + IntToStr(Y) + '-' + inttofix2str(M) + '-' + IntToFix2Str(D) + ' ';
end;
result := result + Subj;
end;

function TTask.TableString : utf8string;
begin
if Subj = '' then Exit('');
result := '';
if Done then result := result + 'x|' else result := result + ' |';
if PrioExists then begin
 result := result + '(' + Prio + ')|';
end else result := result + '   |';
if Y <> 0 then begin
 result := result + IntToStr(Y) + '-' + inttofix2str(M) + '-' + IntToFix2Str(D) + '|';
end else result := result + '          |';
result := result + Subj;
end;

function TTask.ImportString(s : utf8string) : bytebool;
var
 tmp : utf8string = '';
 tm, td : Int64;
begin
if Length(s) < 2 then begin
 Subj := s;
 Y := 0;
 Done := false;
 Exit(false);
end;
Done := Copy(s, 1, 2) = 'x ';
if Done then tmp := Copy(s,3,Length(s)-2) else tmp := s;
PrioExists := false;
if (tmp[1] = '(') and (tmp[3] = ')') then begin
 if tmp[2] in ['A'..'Z'] then begin
  Prio := tmp[2];
  PrioExists := true;
  tmp := Copy(tmp,5,Length(tmp)-4);
 end else begin
  Subj := tmp;
  Exit(false);
 end;
end;
if Length(tmp) > 10 then begin
if (tmp[5] = '-') and (tmp[8] = '-') and
 isDigit(tmp[1]) and isDigit(tmp[2]) and
 isDigit(tmp[3]) and isDigit(tmp[4]) and
 isDigit(tmp[6]) and isDigit(tmp[7]) and
 isDigit(tmp[9]) and isDigit(tmp[10]) then begin
Y := StrToIntDef(Copy(tmp,1,4),0);
if Y <> 0 then begin
 tm := StrToIntDef(Copy(tmp,6,2),0);
 if (tm = 0) or (tm > 12) then Exit(true) else M := tm;
 td := StrToIntDef(Copy(tmp,9,2),0);
 if (td = 0) or (td > 31) then Exit(true) else D := td;
 tmp := Copy(tmp, 12, Length(tmp)-11);
 end;
end else Y := 0;
end else Y := 0;
subj := tmp;
Exit(false);
end;

procedure TTasks.ReadFile;
var
 s : utf8string = '';
 t : TTask;
 c : Int64 = 0;
begin
filter := false;
	WriteLn('Loading tasks... ', fn_todo);
	AssignFile(fpi,fn_todo);
	FileMode := 2;
	{$I-}
	ReSet(fpi);
	{$I+}	if IOResult <> 0 then begin
		{$I-}
		ReWrite(fpi);
		{$I+}	if IOResult <> 0 then begin
			WriteLn('Error reset file'); Halt(1);
			end;
		{$I-}
		ReSet(fpi);
		{$I+}	if IOResult <> 0 then begin
			WriteLn('Error reset file'); Halt(1);
			end;
		end;
SetLength(ts.a, 0);
	while not eof(fpi) do begin
	Inc(c);
	{$I-}
	ReadLn(fpi, s);
	{$I+}	if IOResult <> 0 then begin
		WriteLn('Error read file'); Halt(1);
		end;
	if t.ImportString(s) then WriteLn('Bad format string No ', c, ' ignore it')
	else ts.Add(t);
	end;

	{$I-}
	Close(fpi);
	{$I+} if IOResult <> 0 then begin WriteLn('Error close file'); Halt(1); end;
	WriteLn('Ok');
saved := true;
end;

function TTasks.SaveFile : bytebool;
var
 f : Int64;
begin
if Length(a) < 1 then Exit(false);
AssignFile(fpi,fn_todo);
FileMode := 1;
{$I-}
ReWrite(fpi);
{$I+}	if IOResult <> 0 then begin
	WriteLn('Error rewrite file'); Exit(true);
	end;
for f := 0 to High(a) - 1 do begin
{$I-}
WriteLn(fpi, a[f].ExportString);
{$I+}	if IOResult <> 0 then begin
	WriteLn('Error write file'); break;
	end;
end;
{$I-}
Write(fpi, a[High(a)].ExportString);
{$I+}	if IOResult <> 0 then begin
	WriteLn('Error write file');
	end;
{$I-}
Close(fpi);
{$I+} if IOResult <> 0 then begin WriteLn('Error close file'); Exit(true); end;
saved := true;
Exit(false);
end;
procedure TTasks.DoSave;
begin
 WriteLn('Saving tasks... ', fn_todo);
 if SaveFile then begin WriteLn('Error save tasks file'); Halt(1); end else
 WriteLn('Ok');
end;

procedure TTasks.DoSortEx(s : utf8string);
begin
	if Pos('PRIORITY', s) <> 0 then
		Sort('P')
	else if Pos('DATE', s) <> 0 then
		Sort('D')
	else
		WriteLn('Bad sort method');
end;

// Compares two tasks

function TTasks.Comp(i, j : Int64; t : char) : bytebool;
var
 dif : Int64 = 0;
begin
if a[i].Done <> a[j].Done then Exit(a[i].Done > a[j].Done);
// Type 'P' : Done, priority, date, subject
// Type 'D' : Done, date, priority, subject
case t of
'P' : begin
dif := Ord(a[i].Prio) - Ord(a[j].Prio);
if dif <> 0 then Exit(a[i].Prio > a[j].Prio);
if not ( (a[i].Y = a[j].Y) and (a[i].M = a[j].M) and (a[i].D = a[j].D) ) then begin
 if a[i].Y > a[j].Y then Exit(true);
 if (a[i].Y = a[j].Y) and (a[i].M > a[j].M) then Exit(true);
 if (a[i].Y = a[j].Y) and (a[i].M = a[j].M) and (a[i].D > a[j].D) then Exit(true);
Exit(false);
end;
end;
'D' : begin
if not ( (a[i].Y = a[j].Y) and (a[i].M = a[j].M) and (a[i].D = a[j].D) ) then begin
 if a[i].Y > a[j].Y then Exit(true);
 if (a[i].Y = a[j].Y) and (a[i].M > a[j].M) then Exit(true);
 if (a[i].Y = a[j].Y) and (a[i].M = a[j].M) and (a[i].D > a[j].D) then Exit(true);
Exit(false);
end;
dif := Ord(a[i].Prio) - Ord(a[j].Prio);
if dif <> 0 then Exit(a[i].Prio > a[j].Prio);
end;
end;
Exit(strcomp(PChar(a[i].Subj), PChar(a[j].Subj)) > 0);
end;

// Swap two tasks

procedure TTasks.Swap(i, j : Int64);
var
tmp : TTask;
begin
tmp := a[j];
a[j] := a[i];
a[i] := tmp;
end;

procedure TTasks.Sort(c : char);
var
i,j : Int64;
begin
WriteLn('Sorting... ');
for i := 0 to High(a) do
 for j := i + 1 to High(a) do
  if Comp(i, j, c) then Swap(i, j); (* (a[i] > a[j]) *)
WriteLn('Ok');
end;

function TTasks.ChkFilter(i : Int64) : bytebool;
var
match : Int64 = 0;
begin
	if ft.Done then begin
	 if a[i].Done then begin Inc(match) end;
	end else Inc(match);
	if ft.PrioExists then begin
	 if ft.Prio = a[i].Prio then begin Inc(match) end;
	end else Inc(match);
{
	if ft.Y <> 0 then begin
	 if (a[i].Y = ft.Y) and (a[i].M = ft.M) and (a[i].D = ft.D) then begin Inc(match) end;
	end else Inc(match);
}
	if ft.InputedDate <> '' then begin
	 if Pos(ft.InputedDate, IntToStr(a[i].Y) + '-' + IntToFix2Str(a[i].M) + '-' + IntToFix2Str(a[i].D)) <> 0 then begin Inc(match); end;
	end else Inc(match);
	if ft.Subj <> '' then begin
	 if Pos(ft.Subj, a[i].Subj) <> 0 then begin Inc(match) end;
	end else Inc(match);
	Exit(match <> 4);
end;

procedure TTasks.DoFilter;
begin
ft.AskTask(true, true);
filter := ft.Done or ft.PrioExists or (ft.Y <> 0) or (ft.Subj <> '') or (ft.InputedDate <> '');
end;

procedure TTasks.DoFilterEx(s : utf8string);
begin
if Pos('OFF', s) <> 0 then filter := FALSE
else WriteLn('Bad option');
end;

function TTasks.DoQuit : bytebool;
begin
if saved = FALSE then Exit(AreYouSure('There is unsaved data'));
Exit(TRUE);
end;

procedure TTasks.Intro;
begin
WriteLn('WTD - What To Do: A ''to do list'' manager');
WriteLn('v1.01 for CP/M & Z80');
WriteLn('(c) 2014 Floppy Software. Valencia (Spain).');
WriteLn('www.floppysoftware.vacau.com');
WriteLn('cpm-connections.blogspot.com.es');
WriteLn('floppysoftware@gmail.com');
WriteLn;
WriteLn('v2.00 for GNU/Linux & x86_64');
WriteLn('(c) 2024 Artyomov Alexander');
WriteLn('http://soft.self-made-free.ru/');
WriteLn('https://foss-ru.livejournal.com/');
WriteLn('aralni@mail.ru');

end;

procedure TTasks.DoHelp;
begin
	WriteLn('Help summary:');
	WriteLn('ADD     {task def}       : Add task');
	WriteLn('EDIT    task-number      : Edit task');
	WriteLn('KILL    task-number      : Kill (delete) task');
	WriteLn('DONE    task-number      : Set task as done');
	WriteLn('PENDING task-number      : Set task as pending');
	WriteLn('SORT    PRIORITY | DATE  : Sort tasks by Priority or by Date');
	WriteLn('FILTER  {OFF}            : Set filters for Print option');
	WriteLn('PACK                     : Kill all done tasks');
	WriteLn('PRINT   {how-many-tasks} : Print tasks on screen');
	WriteLn('SAVE                     : Save taks on disk');
	WriteLn('HELP                     : This option');
	WriteLn('QUIT                     : End program');
	WriteLn('task def = {priority} {date} subject');
	WriteLn('I.E.     = (B) 2014-08-16 Call Peter +Party @Phone');
	WriteLn('         = Paint kitchen +Home');
	WriteLn('Items between {} are optional.');
end;

type
	TCmd = record
	c, p : utf8string;
	end;

function ParseCmd(s : utf8string) : TCmd;
var
 f, l, e : Int64;
function ps(c : utf8char) : bytebool; register;
begin
Exit((s[f] <> ' ') and (s[f] <> '      '));
end;
begin
with result do begin
c := ''; p := ''; e := 0;
end; {w}
l := Length(s);
for f := 1 to l do begin
case e of
0: if ps(s[f]) then begin e := 1; result.c := s[f]; end;
1: if ps(s[f]) then result.c := result.c + s[f] else e := 2;
2: if ps(s[f]) then begin e := 3; result.p := s[f]; end;
3: result.p := result.p + s[f];
end;
end; {next f}
end;

procedure TTasks.Menu;
var
stop : boolean;
buf : utf8string;
c : TCmd;
begin
stop := false; // buf := kbf_subj;

	while(stop = false) do begin
		WriteLn('Command (HELP for help)? ');
		ReadLn(buf);
		WriteLn;

		if buf = '' then continue;

c := ParseCmd(buf);

     if c.c = 'ADD' then begin if c.p = '' then DoAddTask else DoAddTaskEx(c.p); end
else if c.c = 'FILTER' then begin if c.p = '' then DoFilter else DoFilterEx(c.p); end
else if c.c = 'PACK' then begin DoPack; end
else if c.c = 'PRINT' then begin if c.p = '' then DoPrint else DoPrintEx(StrToIntDef(c.p, 1)); end
else if c.c = 'SAVE' then begin DoSave; end
else if c.c = 'HELP' then begin DoHelp; end
else if c.c = 'QUIT' then begin if DoQuit then Halt; end
else if c.c = 'EDIT' then begin DoChgTaskEx(StrToIntDef(c.p, -1)); end
else if c.c = 'KILL' then begin DoKillTaskEx(StrToIntDef(c.p, -1)); end
else if c.c = 'DONE' then begin DoDoneTaskEx(StrToIntDef(c.p, -1)); end
else if c.c = 'PENDING' then begin DoPendTaskEx(StrToIntDef(c.p, -1)); end
else if c.c = 'SORT' then begin DoSortEx(c.p); end
		else
			WriteLn('Bad command or syntax error');
	end;
end;

begin
with ts do begin
Intro;
ReadFile;
Menu;
end;
end.