unit ReefSettings;

{ The settings, kept on Windows in the registry under HKEY_CURRENT_USER\Software\Reefscape\Settings,
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
    Screens: string;    // with several screens: span | same | each | main
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
  ScreenModes: array [0 .. 3] of TChoice = (
    (Key: 'span'; Caption: 'One wide reef across all screens'),
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
  {$IFDEF MSWINDOWS}Winapi.Windows, System.Win.Registry,{$ENDIF}
  System.IniFiles, System.IOUtils;

function TReefSettings.IsOff(const Key: string): Boolean;
begin
  Result := Pos(',' + Key + ',', ',' + Off + ',') > 0;
end;

{ Windows keeps the settings in the registry (shared by the screensaver and the FMX app);
  other systems in Reefscape.ini in the user's home folder }
function OpenStore(ReadOnly: Boolean): TCustomIniFile;
begin
{$IFDEF MSWINDOWS}
  if ReadOnly then
    Result := TRegistryIniFile.Create('Software\Reefscape', KEY_READ)
  else
    Result := TRegistryIniFile.Create('Software\Reefscape');
{$ELSE}
  Result := TMemIniFile.Create(TPath.Combine(TPath.GetHomePath, 'Reefscape.ini'));
{$ENDIF}
end;

procedure TReefSettings.Load;
var
  Ini: TCustomIniFile;
begin
  Self := Default(TReefSettings);
  StartHour := -1;
  Ini := OpenStore(True);
  try
    Light := Ini.ReadString('Settings', 'Light', 'auto');
    Clock := Ini.ReadString('Settings', 'Clock', 'off');
    Count := Ini.ReadString('Settings', 'Count', 'few');
    Off := Ini.ReadString('Settings', 'Off', '');
    Screens := Ini.ReadString('Settings', 'Screens', 'span');
  finally
    Ini.Free;
  end;
end;

procedure TReefSettings.Save;
var
  Ini: TCustomIniFile;
begin
  Ini := OpenStore(False);
  try
    Ini.WriteString('Settings', 'Light', Light);
    Ini.WriteString('Settings', 'Clock', Clock);
    Ini.WriteString('Settings', 'Count', Count);
    Ini.WriteString('Settings', 'Off', Off);
    Ini.WriteString('Settings', 'Screens', Screens);
    Ini.UpdateFile;
  finally
    Ini.Free;
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
