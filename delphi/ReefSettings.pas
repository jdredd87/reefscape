unit ReefSettings;

{ The screensaver's settings, kept in the registry under HKEY_CURRENT_USER\Software\Reefscape,
  plus test options that can be given on the command line (name=value). }

interface

uses
  System.SysUtils, System.Classes;

type
  TChoice = record
    Key, Caption: string;
  end;

  TReefSettings = record
    Light: string;      // auto | day | sunset | night | cycle
    Clock: string;      // off | time | date | both
    Count: string;      // few | some | lots
    Off: string;        // comma-separated animal keys that are switched off
    Screens: string;    // with several screens: same | each | main
    // test options (command line only, never saved)
    StartHour: Single;  // < 0 = follow the clock
    Show: string;       // send this rare visitor now: puffer | sub | angler
    Season: string;     // xmas = pretend it is December
    Shark, Spawn, Diver, Fish, Shrimp: Boolean;
    function IsOff(const Key: string): Boolean;
    procedure Load;
    procedure Save;
    procedure ApplyArg(const Name, Value: string);
  end;

const
  LightModes: array [0 .. 4] of TChoice = (
    (Key: 'auto'; Caption: 'Follow the clock'),
    (Key: 'day'; Caption: 'Always day'),
    (Key: 'sunset'; Caption: 'Always sunset'),
    (Key: 'night'; Caption: 'Always night'),
    (Key: 'cycle'; Caption: 'Fast day/night cycle'));

  ClockModes: array [0 .. 3] of TChoice = (
    (Key: 'off'; Caption: 'Off'),
    (Key: 'time'; Caption: 'Time'),
    (Key: 'date'; Caption: 'Date'),
    (Key: 'both'; Caption: 'Date and time'));

  // how many swimming animals at once (the fish in the reef's three depth layers)
  CountModes: array [0 .. 2] of TChoice = (
    (Key: 'few'; Caption: 'A few'),
    (Key: 'some'; Caption: 'Some'),
    (Key: 'lots'; Caption: 'Lots'));

  // what to do when the PC has more than one screen
  ScreenModes: array [0 .. 2] of TChoice = (
    (Key: 'same'; Caption: 'The same reef on every screen'),
    (Key: 'each'; Caption: 'A different reef on each screen'),
    (Key: 'main'; Caption: 'Main screen only'));

  // Key = creature kind used by the scene, Caption = what the user sees
  Animals: array [0 .. 24] of TChoice = (
    (Key: 'tang'; Caption: 'Blue tangs'),
    (Key: 'ytang'; Caption: 'Yellow tangs'),
    (Key: 'angel'; Caption: 'Angelfish'),
    (Key: 'clown'; Caption: 'Clownfish'),
    (Key: 'school'; Caption: 'Fish schools'),
    (Key: 'lionfish'; Caption: 'Lionfish'),
    (Key: 'shark'; Caption: 'Reef sharks'),
    (Key: 'turtle'; Caption: 'Sea turtles'),
    (Key: 'manta'; Caption: 'Manta rays'),
    (Key: 'jelly'; Caption: 'Jellyfish'),
    (Key: 'octopus'; Caption: 'Octopus'),
    (Key: 'dolphin'; Caption: 'Dolphins'),
    (Key: 'whale'; Caption: 'Humpback whale'),
    (Key: 'seahorse'; Caption: 'Seahorses'),
    (Key: 'crab'; Caption: 'Crabs'),
    (Key: 'star'; Caption: 'Sea stars'),
    (Key: 'eel'; Caption: 'Moray eel'),
    (Key: 'shrimp'; Caption: 'Snapping shrimp'),
    (Key: 'geel'; Caption: 'Garden eels'),
    (Key: 'spawn'; Caption: 'Coral spawning (full moon)'),
    (Key: 'puffer'; Caption: 'Pufferfish (rare)'),
    (Key: 'angler'; Caption: 'Anglerfish (night)'),
    (Key: 'diver'; Caption: 'Scuba Steve'),
    (Key: 'sub'; Caption: 'Captain Greg'),
    (Key: 'hook'; Caption: 'Fishing hook'));

implementation

uses
  Winapi.Windows, System.Win.Registry;

const
  RegKey = 'Software\Reefscape';

function TReefSettings.IsOff(const Key: string): Boolean;
begin
  Result := Pos(',' + Key + ',', ',' + Off + ',') > 0;
end;

procedure TReefSettings.Load;
var
  Reg: TRegistry;

  function Read(const Name, Default: string): string;
  begin
    if Reg.ValueExists(Name) then Result := Reg.ReadString(Name) else Result := Default;
  end;

begin
  Self := Default(TReefSettings);
  Light := 'auto';
  Clock := 'off';
  Count := 'few';
  Screens := 'same';
  StartHour := -1;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(RegKey) then
    begin
      Light := Read('Light', Light);
      Clock := Read('Clock', Clock);
      Count := Read('Count', Count);
      Off := Read('Off', '');
      Screens := Read('Screens', Screens);
    end;
  finally
    Reg.Free;
  end;
end;

procedure TReefSettings.Save;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(RegKey, True) then
    begin
      Reg.WriteString('Light', Light);
      Reg.WriteString('Clock', Clock);
      Reg.WriteString('Count', Count);
      Reg.WriteString('Off', Off);
      Reg.WriteString('Screens', Screens);
    end;
  finally
    Reg.Free;
  end;
end;

{ test options, e.g.  Reefscape.scr /w hour=22 show=puffer }
procedure TReefSettings.ApplyArg(const Name, Value: string);
begin
  if Name = 'hour' then StartHour := StrToFloatDef(Value, -1, TFormatSettings.Invariant)
  else if Name = 'light' then Light := Value
  else if Name = 'clock' then Clock := Value
  else if Name = 'count' then Count := Value
  else if Name = 'off' then Off := Value
  else if Name = 'screens' then Screens := Value
  else if Name = 'show' then Show := Value
  else if Name = 'season' then Season := Value
  else if Name = 'shark' then Shark := Value = '1'
  else if Name = 'spawn' then Spawn := Value = '1'
  else if Name = 'diver' then Diver := Value = '1'
  else if Name = 'fish' then Fish := Value = '1'
  else if Name = 'shrimp' then Shrimp := Value = '1';
end;

end.
