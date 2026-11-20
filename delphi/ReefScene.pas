unit ReefScene;

{ The reef itself: layers, light, corals, residents, visitors and the day/night cycle.
  A port of components/OceanScene.brs and OceanScene.xml from the Roku version.

  Layers, back to front. Each "cam" group drifts by a different amount, which creates the parallax depth
  effect. Fog posters between layers push distant layers back into the blue.

  Unlike the Roku version the reef has no fixed width. It is 1080 design units high and as wide as the
  window's shape asks for (1920 on a 16:9 screen, 2560 on a 21:9 one, 5760 across three screens...).
  The backgrounds and the reef's fixed residents repeat in "sections", every other one mirrored so the joins
  are seamless, and the swimmers cross the whole width. }

interface

uses
  Winapi.Windows, Winapi.OpenGL, System.SysUtils, System.Classes, System.Math, System.StrUtils, System.DateUtils,
  System.Generics.Collections, ReefEngine, ReefSpecs, ReefCreature, ReefSettings;

type
  TLayer = (lFar, lMid, lNear, lFarBack, lJelly);

  TSlot = class
  public
    Layer: TLayer;
    Amp, Rest, DMin, DMax, YMin, YMax, Range, Period, First, GapMin, GapMax: Single;
    Kinds, NightKinds: TArray<string>;
    Mode: TMode;
    HasRange, HasFirst, DayOnly, NightOnly: Boolean;
    Home: TVec2;
    Dens, Pod, Pending: Integer;
    Nodes: TArray<TCreature>;
    Due: Double;
    Kind, ForceKind: string;
  end;

  TTwin = record
    Kind: string;
    Node: TCreature;
  end;

  TGeel = record
    X, H: Single;             // X = where it is in the reef (not in its section)
    Inner: TNode;
    Anim: TAnim;
  end;

  { one colony of garden eels (there is one in every section of the reef) }
  TColony = record
    Eels: TArray<TGeel>;
    X0, X1: Single;
    Down: Boolean;
    UpAt, Solo: Double;
  end;

  { the snapping shrimp of one section's sponge }
  TShrimp = record
    Clip, G, Inner, Body, Finger, Bub: TNode;
    Anim: TAnim;
    Last: Integer;
    Dx, X, Y, S, Open: Single;   // Dx = how far this section's sponge is from the original place
    Tip: TVec2;
  end;

  TSpawnDot = record
    P: TNode;
    Anim: TAnim;
    FreeAt: Double;
  end;

  TLive = record
    Kind: string;
    X, Y, S: Single;
    Node: TCreature;
  end;

  TTextLabel = record
    Node: TNode;
    Tex: TTexture;
    Size: Integer;
    Bold: Boolean;
    Y: Single;
  end;

  TOceanScene = class
  private
    FSet: TReefSettings;
    FRoot: TNode;
    FAnim: TAnimator;
    FSpecs: TSpecs;
    FNow: Double;           // milliseconds since the scene started
    FTickAcc: Single;
    FUid: Integer;
    FW: Single;             // width of the reef in design units
    FWide: Integer;         // how many 16:9 screens wide it is (at least 1)
    FNearN, FMidN: Integer; // sections of the near and middle layers
    FView: TMat;
    FWinW, FWinH: Integer;
    FViewScale, FVX0, FVY0, FVX1, FVY1: Single;
    FClockArea: TRect;
    FHasClockArea: Boolean;
    // layers
    FCams: array [0 .. 8] of TNode;
    FCamAmp: array [0 .. 8] of Single;
    FLayers: array [TLayer] of TNode;
    FNearDecor, FMidDecor, FSurface, FRays, FCaustics, FBubbles, FGardenEels, FFishing, FParticles: TNode;
    FNearSec: TArray<TNode>;
    FNightShade, FWarm, FFarLight, FMidLight, FGlow, FMoonGlow, FSpawnG: TNode;
    // light
    FHour, FDay, FTimeOffset, FCycleStart, FMoonK, FFromFull: Single;
    FCycleT0, FMoonCheckAt: Double;
    FForceSpawn: Boolean;
    FSeason: string;
    FSeasonFixed: Boolean;
    FDensity: Integer;
    // residents
    FShrimps: TArray<TShrimp>;
    FShrimpNext: Double;
    FColonies: TArray<TColony>;
    // coral spawning
    FSpawnPool: TArray<TSpawnDot>;
    FSpawnNext: Double;
    // clock
    FClockGrp: TNode;
    FLabels: array [0 .. 3] of TTextLabel;   // time shadow, time, date shadow, date
    FClockIdx: Integer;
    FClockText, FClockPhase: string;
    FClockMoveAt: Double;
    FClockOut, FClockIn: TAnim;
    FClockOn: Boolean;
    // fishing
    FHookGroup, FBait: TNode;
    FThief: TCreature;
    FHookAnim: TAnim;
    FHookPos: TVec2;
    FFishState: string;
    FFishNext, FBiteAt: Double;
    // creatures
    FSlots: TObjectList<TSlot>;
    FCreatures: TObjectList<TCreature>;
    FTwins: TDictionary<string, TTwin>;
    FDiverSlot, FPufferSlot, FCloseSlot: Integer;
    function Off(const Key: string): Boolean;
    function FullPoster(Parent: TNode; const Img: string; Opacity: Single): TNode;
    procedure Tile(Parent: TNode; const Img: string; X0, Y, W, H, Amp: Single);
    function SecCount(Period, Amp, X0: Single): Integer;
    function SecGroup(Parent: TNode; K: Integer; Period: Single): TNode;
    function SecX(K: Integer; Period, X: Single): Single;
    procedure BuildLight;
    procedure BuildCaustics;
    procedure BuildDecor;
    procedure BuildBubbles;
    procedure BuildParticles;
    procedure BuildEel(K: Integer);
    procedure BuildShrimp(K: Integer);
    procedure PlaceShrimp(var Sh: TShrimp; I: Integer; Flip: Boolean);
    procedure UpdateShrimp;
    procedure BuildPlankton;
    procedure BuildGardenEels(K: Integer);
    procedure MoveGeel(var E: TGeel; ToY, Duration, Delay: Single; Ease: TEase);
    function GeelThreat(const Col: TColony; out X: Single): Boolean;
    procedure UpdateGardenEels;
    function LiveCreatures(Layer: TLayer): TArray<TLive>;
    procedure UpdateScatter;
    function MoonFromFull: Single;
    procedure BuildSpawning;
    procedure SetMoon;
    procedure ReleaseSpawn(K: Integer);
    procedure UpdateSpawning;
    function CurrentHour: Single;
    procedure UpdateLight;
    procedure BuildClock;
    procedure ApplyClock;
    procedure PlaceClock(I: Integer);
    procedure SetLabel(Index: Integer; const Text: string);
    procedure UpdateClockText;
    procedure TickClock;
    procedure BuildFishing;
    procedure MoveHook(const Keys: array of Single; const Vals: array of TVec2; Duration: Single; Ease: TEase);
    procedure UpdateFishing;
    procedure StartFishing;
    procedure OnBite;
    function CurrentSeason: string;
    procedure BuildSlots;
    function NewSlot(Layer: TLayer; Amp: Single; const Kinds: array of string; DMin, DMax, YMin, YMax, GapMin,
      GapMax: Single): TSlot;
    procedure AddSlot(Sl: TSlot);
    procedure AddLayer(Layer: TLayer; Amp: Single; Count: Integer; const Kinds, NightKinds: array of string;
      DMin, DMax, YMin, YMax: Single);
    procedure SpawnSlot(I: Integer; Initial: Boolean);
    procedure CreatureDone(C: TCreature);
    procedure ApplyTestOptions;
    procedure Tick;
  public
    { needs a current OpenGL context: images are loaded as the scene is built.
      The window's shape at this moment decides how wide the reef is. }
    constructor Create(const ASettings: TReefSettings; WinW, WinH: Integer);
    destructor Destroy; override;
    procedure SetView(WinW, WinH: Integer);
    { where the clock may sit (window pixels), e.g. the main screen when the reef spans several }
    procedure SetClockArea(const R: TRect);
    procedure Advance(Dt: Single);
    { draws into the part of the window whose bottom-left corner is at (OriginX, OriginY) }
    procedure Render(OriginX: Integer = 0; OriginY: Integer = 0);
  end;

implementation

const
  AmpFar = 25;
  AmpMid = 60;
  AmpLight = 40;
  AmpNear = 110;
  AmpFront = 160;
  AmpJelly = 60;
  AmpGlow = 120;
  // how often each layer's background repeats (the width of its image as drawn)
  FarPeriod = 2000;
  MidPeriod = 2080;
  NearPeriod = 2200;

type
  { Where a section's corals stand, as shifts from the original reef. Even sections use the original layout;
    odd ones (which are also mirrored) a rearranged one, so a join does not look like a reflection. }
  TLayout = record
    Alt: Boolean;
    Rock, Sponge, Stag2, Anemone: Single;
  end;

function Layout(K: Integer): TLayout;
begin
  Result := Default(TLayout);
  if Odd(K) then
  begin
    Result.Alt := True;
    Result.Rock := -1380;     // the rock (with its moray eel and sea fan) moves to the other end
    Result.Sponge := 215;
    Result.Stag2 := 60;
    Result.Anemone := 960;
  end;
end;

function Smoothstep(X: Single): Single;
begin
  X := EnsureRange(X, 0, 1);
  Result := X * X * (3 - 2 * X);
end;

function Strs(const A: array of string): TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, Length(A));
  for I := 0 to High(A) do Result[I] := A[I];
end;

{ ---------- construction ---------- }

constructor TOceanScene.Create(const ASettings: TReefSettings; WinW, WinH: Integer);
var
  CamFar, CamMid, CamLight, CamNear, CamFront, CamFarLight, CamMidLight, CamGlow, CamJelly: TNode;
  K: Integer;
begin
  FSet := ASettings;
  FAnim := TAnimator.Create;
  FSpecs := BuildSpecs;
  FSlots := TObjectList<TSlot>.Create(True);
  FCreatures := TObjectList<TCreature>.Create(True);
  FTwins := TDictionary<string, TTwin>.Create;
  FRoot := TNode.Create(nkGroup);
  SetView(WinW, WinH);
  FWide := Max(1, Round(FW / 1920));
  FNearN := SecCount(NearPeriod, AmpNear, -140);
  FMidN := SecCount(MidPeriod, AmpMid, -80);

  // how many fish slots are in use: 0 = a few, 1 = some, 2 = lots (all)
  FDensity := 0;
  if FSet.Count = 'some' then FDensity := 1;
  if FSet.Count = 'lots' then FDensity := 2;
  FSeason := CurrentSeason;

  FullPoster(FRoot, 'bg_water', 1);

  CamFar := FRoot.AddGroup('camFar');
  FLayers[lFarBack] := CamFar.AddGroup('farBack');
  Tile(CamFar, 'reef_far', -40, 520, FarPeriod, 440, AmpFar);
  FLayers[lFar] := CamFar.AddGroup('farCreatures');

  FullPoster(FRoot, 'bg_water', 0.38);   // fog

  CamMid := FRoot.AddGroup('camMid');
  Tile(CamMid, 'reef_mid', -80, 580, MidPeriod, 520, AmpMid);
  FMidDecor := CamMid.AddGroup('midDecor');
  FLayers[lMid] := CamMid.AddGroup('midCreatures');

  FullPoster(FRoot, 'bg_water', 0.14);   // fog

  CamLight := FRoot.AddGroup('camLight');
  FSurface := CamLight.AddGroup('surfaceGroup');
  FRays := CamLight.AddGroup('rays');

  CamNear := FRoot.AddGroup('camNear');
  Tile(CamNear, 'sand', -140, 790, NearPeriod, 300, AmpNear);
  FNearDecor := CamNear.AddGroup('nearDecor');
  FBubbles := CamNear.AddGroup('bubbles');
  Tile(CamNear, 'sand_front', -140, 885, NearPeriod, 250, AmpNear);
  FCaustics := CamNear.AddGroup('caustics');
  FGardenEels := CamNear.AddGroup('gardenEels');
  FLayers[lNear] := CamNear.AddGroup('nearCreatures');
  FFishing := CamNear.AddGroup('fishing');

  CamFront := FRoot.AddGroup('camFront');
  FParticles := CamFront.AddGroup('particles');

  // day/night: the night shade and warm sunrise/sunset light; anything after these stays bright (glows)
  FNightShade := FRoot.AddRect(FW, 1080, $020A1C);
  FNightShade.Opacity := 0;
  FWarm := FullPoster(FRoot, 'warm_grad', 0);

  // Scuba Steve's torch beam at night: moves with the far layer, drawn above the night shade
  CamFarLight := FRoot.AddGroup('camFarLight');
  FFarLight := CamFarLight.AddGroup('farLight');
  // the anglerfish's glowing lure: moves with the middle layer
  CamMidLight := FRoot.AddGroup('camMidLight');
  FMidLight := CamMidLight.AddGroup('midLight');

  CamGlow := FRoot.AddGroup('camGlow');
  FGlow := CamGlow.AddGroup('plankton');
  FGlow.Opacity := 0;
  // full-moon nights: the moon glowing through the surface, and coral spawning
  FMoonGlow := CamGlow.AddPoster('moon_glow').Size(128, 128).Pos(FW / 2 - 60, -190).Scale(7, 3);
  FMoonGlow.Opacity := 0;
  FMoonGlow.Visible := False;
  FSpawnG := CamGlow.AddGroup('spawning');

  // jellyfish live above the night shade so they glow in the dark
  CamJelly := FRoot.AddGroup('camJelly');
  FLayers[lJelly] := CamJelly.AddGroup('jellyCreatures');

  FullPoster(FRoot, 'vignette', 1);
  FClockGrp := FRoot.AddGroup('clockGrp');

  // camera sway (parallax): each layer drifts by its own amount
  FCams[0] := CamFar;       FCamAmp[0] := AmpFar;
  FCams[1] := CamMid;       FCamAmp[1] := AmpMid;
  FCams[2] := CamLight;     FCamAmp[2] := AmpLight;
  FCams[3] := CamNear;      FCamAmp[3] := AmpNear;
  FCams[4] := CamFront;     FCamAmp[4] := AmpFront;
  FCams[5] := CamJelly;     FCamAmp[5] := AmpJelly;
  FCams[6] := CamGlow;      FCamAmp[6] := AmpGlow;
  FCams[7] := CamFarLight;  FCamAmp[7] := AmpFar;
  FCams[8] := CamMidLight;  FCamAmp[8] := AmpMid;

  // the fast cycle starts at the real time of day
  FCycleStart := Frac(Now) * 24;
  if FSet.StartHour >= 0 then
  begin
    FSet.Light := 'auto';
    FTimeOffset := FSet.StartHour - Frac(Now) * 24;
  end;

  BuildLight;
  BuildDecor;
  SetLength(FShrimps, FNearN);
  SetLength(FColonies, FNearN);
  for K := 0 to FNearN - 1 do
  begin
    BuildEel(K);
    BuildShrimp(K);
    BuildGardenEels(K);
  end;
  FShrimpNext := Rnd(20, 40) * 1000;
  FGardenEels.Visible := not Off('geel');
  BuildCaustics;
  BuildBubbles;
  BuildParticles;
  BuildPlankton;
  BuildSpawning;
  BuildClock;
  BuildFishing;
  if FSet.Spawn then
  begin
    FForceSpawn := True;
    SetMoon;
  end;
  if FSet.Season <> '' then
  begin
    FSeason := FSet.Season;
    FSeasonFixed := True;
  end;
  UpdateLight;
  BuildSlots;
  ApplyClock;
  ApplyTestOptions;
  Advance(0);
end;

destructor TOceanScene.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FLabels) do FLabels[I].Tex.Free;
  FThief.Free;
  FTwins.Free;
  FCreatures.Free;
  FSlots.Free;
  FAnim.Free;
  FRoot.Free;
  FSpecs.Free;
  inherited;
end;

function TOceanScene.Off(const Key: string): Boolean;
begin
  Result := FSet.IsOff(Key);
end;

{ an image stretched over the whole reef (water, fog, sunset light, vignette) }
function TOceanScene.FullPoster(Parent: TNode; const Img: string; Opacity: Single): TNode;
begin
  Result := Parent.AddPoster(Img).Size(FW, 1080);
  Result.Opacity := Opacity;
end;

{ A background image repeated across the reef. Every other copy is mirrored, so each join is an edge meeting
  its own reflection and no seam shows. }
procedure TOceanScene.Tile(Parent: TNode; const Img: string; X0, Y, W, H, Amp: Single);
const
  Overlap = 8;
var
  K: Integer;
  P: TNode;
begin
  for K := 0 to SecCount(W, Amp, X0) - 1 do
  begin
    // drawn a touch wider than its slot: the outermost pixels of some images are see-through, and without
    // the overlap the water would show as a hairline at the join
    P := Parent.AddPoster(Img).Size(W + 2 * Overlap, H);
    if Odd(K) then P.Pos(X0 + (K + 1) * W + Overlap, Y).Scale(-1, 1) else P.Pos(X0 + K * W - Overlap, Y);
  end;
end;

{ how many sections of the given width cover the reef (plus the layer's sway) }
function TOceanScene.SecCount(Period, Amp, X0: Single): Integer;
begin
  Result := Max(1, Ceil((FW + Amp - X0) / Period - 0.001));
end;

{ A group for section K of a layer: things are placed in it with the coordinates of the original 1920-wide
  reef. Odd sections are mirrored, like their background. }
function TOceanScene.SecGroup(Parent: TNode; K: Integer; Period: Single): TNode;
begin
  Result := Parent.AddGroup;
  if Odd(K) then Result.Pos(K * Period + 1920, 0).Scale(-1, 1) else Result.Pos(K * Period, 0);
end;

{ where a section's x lies in the whole reef }
function TOceanScene.SecX(K: Integer; Period, X: Single): Single;
begin
  if Odd(K) then Result := K * Period + 1920 - X else Result := K * Period + X;
end;

{ The window's shape sets the reef's width once; after that the reef is scaled to fill the window, so nothing
  outside it shows. A window less wide than 16:9 crops a little (mostly from the top, so the sand stays). }
procedure TOceanScene.SetView(WinW, WinH: Integer);
var
  S: Single;
begin
  FWinW := Max(1, WinW);
  FWinH := Max(1, WinH);
  if FW = 0 then FW := MaxF(1920, 1080 * FWinW / FWinH);
  S := MaxF(FWinW / FW, FWinH / 1080);
  FViewScale := S;
  FView.A := S;
  FView.B := 0;
  FView.C := 0;
  FView.D := S;
  FView.E := (FWinW - FW * S) / 2;
  FView.F := (FWinH - 1080 * S) * 0.7;
  FVX0 := -FView.E / S;
  FVY0 := -FView.F / S;
  FVX1 := FVX0 + FWinW / S;
  FVY1 := FVY0 + FWinH / S;
end;

procedure TOceanScene.SetClockArea(const R: TRect);
begin
  FClockArea := R;
  FHasClockArea := True;
  if FClockOn then PlaceClock(FClockIdx);
end;

{ ---------- sunlight: rippling surface + light shafts ---------- }

procedure TOceanScene.BuildLight;
const
  Xs: array [0 .. 5] of Single = (120, 480, 820, 1150, 1480, 1760);
var
  I, S: Integer;
  X: Single;
  P: TNode;
  A: TAnim;
begin
  FSurface.Pos(-200, -24);
  // stored at half size; the strip slides left by one image and starts again
  for I := 0 to Ceil((FW + AmpLight + 2249) / 2049) - 1 do FSurface.AddPoster('surface').Size(2049, 320).Pos(I * 2049, 0);
  A := FAnim.New(90, True);
  A.KeysV(FSurface, fTranslation, [0, 1], [V(-200, -24), V(-2249, -24)]);
  A.Start;

  for S := 0 to Ceil(FW / 1920) - 1 do
    for I := 0 to High(Xs) do
    begin
      X := Xs[I] + S * 1920;
      if X > FW + 150 then Continue;
      // ray.png is stored at half size, so it is scaled 2x
      P := FRays.AddPoster('ray').Pos(X + Rnd(-60, 60), -60).Pivot(100, 0).Scale(Rnd(1.2, 2.6), 2.0);
      P.Rot := Rnd(0.16, 0.26);
      FAnim.LoopF(P, fOpacity, 0.3, 0.2, Rnd(7, 13), Rnd(0, 6.28));
    end;
end;

{ ---------- caustics: rippling light network on the sea floor ---------- }

procedure TOceanScene.BuildCaustics;
var
  I, K: Integer;
  Lg: TNode;
  A: TAnim;
begin
  for I := 0 to 1 do
  begin
    Lg := FCaustics.AddGroup;
    Lg.Opacity := IfThen(I = 0, 0.24, 0.17);
    Lg.Scale(1, 0.9);
    for K := 0 to Ceil((FW + AmpNear + 1326) / 1026) - 1 do
      Lg.AddPoster(IfThen(I = 0, 'caustics_a', 'caustics_b')).Size(1026, 256).Pos(K * 1026, 0);
    // the two layers slide in opposite directions
    A := FAnim.New(IfThen(I = 0, 40, 57), True);
    if I = 0 then
      A.KeysV(Lg, fTranslation, [0, 1], [V(-300, 845), V(-1326, 845)])
    else
      A.KeysV(Lg, fTranslation, [0, 1], [V(-1326, 850), V(-300, 850)]);
    A.Start;
  end;
end;

{ ---------- corals, kelp and plants ---------- }

type
  TDecor = record
    Uri: string;
    X, Y, Rot, Period, Px, Py, ScX, ScY: Single;
  end;

function D(const Uri: string; X, Y: Single; Rot: Single = 0; Period: Single = 0; Px: Single = 0; Py: Single = 0;
  ScX: Single = 0; ScY: Single = 0): TDecor;
begin
  Result.Uri := Uri;
  Result.X := X;
  Result.Y := Y;
  Result.Rot := Rot;
  Result.Period := Period;
  Result.Px := Px;
  Result.Py := Py;
  Result.ScX := ScX;
  Result.ScY := ScY;
end;

procedure TOceanScene.BuildDecor;
var
  K: Integer;
  L: TLayout;

  procedure AddDecor(Parent: TNode; const Items: array of TDecor; Tinted: Boolean; Scl: Single);
  var
    It: TDecor;
    P: TNode;
  begin
    for It in Items do
    begin
      P := Parent.AddPoster(It.Uri).Pos(It.X, It.Y);
      P.Name := It.Uri;
      if Tinted then P.SetColor(TintFor(0.5));
      P.Pivot(It.Px, It.Py);
      P.Scale(Scl, Scl);
      if It.Rot <> 0 then FAnim.LoopF(P, fRotation, 0, It.Rot, It.Period, Rnd(0, 6.28));
      if (It.ScX <> 0) or (It.ScY <> 0) then
        FAnim.LoopV(P, fScale, V(Scl, Scl), V(It.ScX, It.ScY), It.Period, Rnd(0, 6.28));
    end;
  end;

begin
  // every section of the reef has its corals; odd sections are mirrored and laid out differently
  SetLength(FNearSec, FNearN);
  for K := 0 to FNearN - 1 do
  begin
    FNearSec[K] := SecGroup(FNearDecor, K, NearPeriod);
    L := Layout(K);
    if L.Alt then
      AddDecor(FNearSec[K], [
        D('kelp', 1090, 130, 0.035, 7.9, 85, 1000),
        D('seafan', 1640 + L.Rock, 495, 0.025, 9, 190, 420),
        D('sponge', 435 + L.Sponge, 575),
        D('seagrass', 650 + L.Anemone, 695, 0.07, 4.5, 110, 240),
        D('seagrass_l', 895 + L.Anemone, 700, 0.06, 5.1, 110, 240),
        D('anemone', 720 + L.Anemone, 690, 0, 5, 160, 240, 0.03, -0.03),
        D('coral_brain', 1010, 725),
        D('coral_stag2', 1290 + L.Stag2, 620),
        D('rock', 1420 + L.Rock, 605)], False, 1.0)
    else
    AddDecor(FNearSec[K], [
      D('kelp', -70, 100, 0.035, 7.5, 85, 1000),
      D('seafan', 1640, 495, 0.025, 9, 190, 420),
      D('coral_stag', 110, 575),
      D('sponge', 435, 575),
      // seagrass on both sides of the anemone, behind it (the right one is the mirrored image)
      D('seagrass', 650, 695, 0.07, 4.5, 110, 240),
      D('seagrass_l', 895, 700, 0.06, 5.1, 110, 240),
      D('anemone', 720, 690, 0, 5, 160, 240, 0.03, -0.03),
      D('coral_brain', 1010, 725),
      D('coral_stag2', 1290, 620),
      D('rock', 1420, 605),
      D('seagrass', 1940, 690, 0.06, 5.2, 110, 240),
      D('kelp', 1840, 150, 0.03, 8.3, 85, 1000)], False, 1.0);
  end;

  for K := 0 to FMidN - 1 do
    AddDecor(SecGroup(FMidDecor, K, MidPeriod), [
      D('kelp', 360, 260, 0.04, 9.5, 85, 1000),
      D('kelp', 1320, 220, 0.035, 8.7, 85, 1000),
      D('seagrass', 900, 760, 0.06, 5.8, 110, 240)], True, 0.75);
end;

{ ---------- bubble streams ---------- }

procedure TOceanScene.BuildBubbles;
const
  Emitters: array [0 .. 2, 0 .. 2] of Integer = ((575, 880, 10), (1170, 880, 6), (1700, 900, 5));
var
  S, E, I, K: Integer;
  G, B: TNode;
  A: TAnim;
  Sz, Ph, X0, T: Single;
  Shift: array [0 .. 2] of Single;
  Keys: array [0 .. 12] of Single;
  Vals: array [0 .. 12] of TVec2;
begin
  for S := 0 to FNearN - 1 do
  begin
    G := SecGroup(FBubbles, S, NearPeriod);
    // the streams rise from the sponge, the brain coral and the rock
    Shift[0] := Layout(S).Sponge;
    Shift[1] := 0;
    Shift[2] := Layout(S).Rock;
    for E := 0 to 2 do
      for I := 0 to Emitters[E, 2] - 1 do
      begin
        B := G.AddPoster('bubble');
        Sz := Rnd(10, 30);
        B.Scale(Sz / 64, Sz / 64);
        B.Opacity := Rnd(0.5, 0.9);
        A := FAnim.New(Rnd(6, 10), True);
        A.Delay := I * Rnd(0.5, 1.1);
        Ph := Rnd(0, 6.28);
        X0 := Emitters[E, 0] + Shift[E] + Rnd(-15, 15);
        for K := 0 to 12 do
        begin
          T := K / 12;
          Keys[K] := T;
          Vals[K] := V(X0 + 14 * Sin(T * 9 + Ph) + T * 40, Emitters[E, 1] - T * 1020);
        end;
        A.KeysV(B, fTranslation, Keys, Vals);
        B.Pos(Vals[0].X, Vals[0].Y);
        A.Start;
      end;
  end;
end;

{ ---------- floating particles ("marine snow") in front of everything ---------- }

procedure TOceanScene.BuildParticles;
var
  I: Integer;
  P: TNode;
  Sz: Single;
  Base: TVec2;
begin
  for I := 0 to Round(45 * FW / 1920) - 1 do
  begin
    P := FParticles.AddPoster('particle');
    Sz := Rnd(3, 11);
    P.Scale(Sz / 32, Sz / 32);
    P.Opacity := Rnd(0.15, 0.5);
    Base := V(Rnd(-150, FW + 150), Rnd(0, 1080));
    P.Pos(Base.X, Base.Y);
    FAnim.LoopV(P, fTranslation, Base, V(Rnd(-60, 60), Rnd(30, 90)), Rnd(16, 34), Rnd(0, 6.28));
  end;
end;

{ ---------- moray eel that peeks out of the rock cave ---------- }

procedure TOceanScene.BuildEel(K: Integer);
var
  Wrap, Outer, Head, Jaw: TNode;
  A: TAnim;
  InP, PeekP, OutP: TVec2;
  Dx: Single;
begin
  Dx := Layout(K).Rock;
  Wrap := FNearSec[K].AddGroup('eelWrap');
  Outer := Wrap.AddGroup;
  Outer.Scale(0.8, 0.8);
  Head := Outer.AddGroup;
  Head.Pivot(255, 78);
  Jaw := Head.AddPoster('eel_jaw').Pos(0, 64).Pivot(90, 8);
  Head.AddPoster('eel');

  // the cave mouth in the rock poster: nothing right of x = 1612 (deep inside the hole) is drawn,
  // so the eel never paints over the rock
  Wrap.SetClip(1150 + Dx, 690, 462, 280);
  Wrap.AddPoster('eel_cave').Pos(1491 + Dx, 764);

  OutP := V(1392 + Dx, 765);
  PeekP := V(1500 + Dx, 765);
  InP := V(1614 + Dx, 765);
  Outer.Pos(InP.X, InP.Y);
  A := FAnim.New(24, True);
  // the eels of different sections keep different hours
  A.Delay := K * 7.5;
  A.KeysV(Outer, fTranslation, [0, 0.12, 0.17, 0.25, 0.33, 0.62, 0.66, 0.72, 1],
    [InP, InP, PeekP, PeekP, OutP, OutP, V(1425 + Dx, 765), InP, InP]);
  A.Start;
  Wrap.Visible := not Off('eel');
  FAnim.LoopF(Jaw, fRotation, 0.13, 0.13, 2.8, 0);
  FAnim.LoopF(Head, fRotation, 0, 0.05, 4.5, 1);
end;

{ ---------- snapping shrimp that pops out of the foreground sponge tubes ---------- }

const
  // tube openings of the sponge poster (sponge at [435,575]): centre x, rim y, shrimp scale
  ShrimpTubes: array [0 .. 3, 0 .. 2] of Single = ((504.6, 695.7, 0.6), (591, 612, 0.6), (661.2, 725.6, 0.56),
    (614.8, 797.4, 0.52));

procedure TOceanScene.BuildShrimp(K: Integer);
var
  I, Idx: Integer;
  Sec: TNode;
begin
  Sec := FNearSec[K];
  // drawn right after the sponge, so plants in front of the sponge stay in front of the shrimp
  Idx := Sec.Count;
  for I := 0 to Sec.Count - 1 do
    if Sec[I].Name = 'sponge' then Idx := I + 1;
  with FShrimps[K] do
  begin
    Clip := Sec.InsertGroup(Idx);
    G := Clip.AddGroup;
    // outer group: position + rotation (pivot at the rim); inner group: scale (about its origin)
    Inner := G.AddGroup;
    Body := Inner.AddPoster('shrimp');
    Finger := Inner.AddPoster('shrimp_finger');
    Bub := Inner.AddPoster('bubble').Pivot(32, 32);
    Bub.Opacity := 0;
    Last := -1;
    Dx := Layout(K).Sponge;
    Anim := FAnim.New(1);
    Clip.Visible := not Off('shrimp');
  end;
  PlaceShrimp(FShrimps[K], 0, False);
end;

{ put the (hidden) shrimp in tube I; Flip = big claw on the left }
procedure TOceanScene.PlaceShrimp(var Sh: TShrimp; I: Integer; Flip: Boolean);
var
  Cx, Cy, S: Single;
begin
  Cx := ShrimpTubes[I, 0] + Sh.Dx;
  Cy := ShrimpTubes[I, 1];
  S := ShrimpTubes[I, 2];
  // only draw above the tube's rim, so the shrimp comes up out of the hole
  Sh.Clip.SetClip(Cx - 80, Cy - 240, 160, 243);
  Sh.Inner.Scale(S, S);
  Sh.G.Pivot(60 * S, 118 * S);
  Sh.G.Rot := 0;
  Sh.X := Cx - 60 * S;
  Sh.Y := Cy;
  Sh.S := S;
  Sh.G.Pos(Sh.X, Cy + 8 * S);
  if Flip then
  begin
    Sh.Body.SetImage('shrimp_l');
    Sh.Finger.SetImage('shrimp_finger_l');
    Sh.Finger.Pos(18, 8).Pivot(18, 28);
    Sh.Tip := V(30, 20);
    Sh.Open := -0.8;
  end
  else
  begin
    Sh.Body.SetImage('shrimp');
    Sh.Finger.SetImage('shrimp_finger');
    Sh.Finger.Pos(78, 8).Pivot(6, 28);
    Sh.Tip := V(90, 20);
    Sh.Open := 0.8;
  end;
  Sh.Finger.Rot := 0;
end;

procedure TOceanScene.UpdateShrimp;
var
  K, Ti: Integer;
  O, T: Single;
  Hid, Peek, Full, Tip, Up, Small, Big: TVec2;
  A: TAnim;
  Sh: TShrimp;
begin
  if FNow < FShrimpNext then Exit;
  if Off('shrimp') then
  begin
    FShrimpNext := FNow + 30000;
    Exit;
  end;
  // one of the sponges whose shrimp is not already out
  K := Random(Length(FShrimps));
  if FShrimps[K].Anim.Running then
  begin
    FShrimpNext := FNow + 2000;
    Exit;
  end;
  // a random tube, never the same one twice in a row
  if FShrimps[K].Last < 0 then
    Ti := Random(Length(ShrimpTubes))
  else
  begin
    Ti := Random(Length(ShrimpTubes) - 1);
    if Ti >= FShrimps[K].Last then Inc(Ti);
  end;
  FShrimps[K].Last := Ti;
  PlaceShrimp(FShrimps[K], Ti, Random < 0.5);
  Sh := FShrimps[K];
  Hid := V(Sh.X, Sh.Y + 8 * Sh.S);
  Peek := V(Sh.X, Sh.Y - 70 * Sh.S);
  Full := V(Sh.X, Sh.Y - 118 * Sh.S);
  O := Sh.Open;
  Tip := V(Sh.Tip.X - 32, Sh.Tip.Y - 32);
  Up := V(Tip.X + 4, Tip.Y - 34);
  Small := V(0.05, 0.05);
  Big := V(0.42, 0.42);
  A := Sh.Anim;
  A.Stop;
  A.ClearTracks;
  if Random < 0.3 then
  begin
    // shy: just peeks, looks around and ducks back in
    T := 5.0;
    A.KeysV(Sh.G, fTranslation, [0, 0.14, 0.7, 0.75, 1], [Hid, Peek, Peek, Hid, Hid]);
    A.KeysF(Sh.G, fRotation, [0, 0.2, 0.35, 0.5, 0.62, 1], [0, 0, 0.12, 0.12, 0, 0]);
    A.KeysF(Sh.Finger, fRotation, [0, 1], [0, 0]);
    A.KeysF(Sh.Bub, fOpacity, [0, 1], [0, 0]);
  end
  else
  begin
    // bold: comes out, looks left and right, snaps its claw twice (pop!), then darts back in
    T := 10.0;
    A.KeysV(Sh.G, fTranslation, [0, 0.07, 0.2, 0.25, 0.76, 0.785, 1], [Hid, Peek, Peek, Full, Full, Hid, Hid]);
    A.KeysF(Sh.G, fRotation, [0, 0.26, 0.34, 0.46, 0.54, 0.66, 0.73, 1], [0, 0, 0.16, 0.16, -0.14, -0.14, 0, 0]);
    A.KeysF(Sh.Finger, fRotation, [0, 0.36, 0.41, 0.46, 0.465, 0.56, 0.6, 0.65, 0.655, 1],
      [0, 0, O, O, 0, 0, O, O, 0, 0]);
    A.KeysF(Sh.Bub, fOpacity, [0, 0.465, 0.47, 0.54, 0.655, 0.66, 0.73, 1], [0, 0, 1, 0, 0, 1, 0, 0]);
    A.KeysV(Sh.Bub, fScale, [0, 0.465, 0.54, 0.655, 0.73, 1], [Small, Small, Big, Small, Big, Big]);
    A.KeysV(Sh.Bub, fTranslation, [0, 0.465, 0.54, 0.655, 0.73, 1], [Tip, Tip, Up, Tip, Up, Up]);
  end;
  A.Duration := T;
  A.Start;
  // a wider reef has more sponges, so a shrimp shows somewhere more often
  FShrimpNext := FNow + (T * 1000 + Rnd(30, 75) * 1000) / Length(FShrimps);
end;

{ ---------- bioluminescent plankton (only visible at night) ---------- }

procedure TOceanScene.BuildPlankton;
var
  I: Integer;
  P: TNode;
  Sz: Single;
  Base: TVec2;
begin
  for I := 0 to Round(70 * FW / 1920) - 1 do
  begin
    P := FGlow.AddPoster('glow_dot');
    Sz := Rnd(5, 16);
    P.Scale(Sz / 32, Sz / 32);
    Base := V(Rnd(-120, FW + 120), Rnd(60, 1060));
    P.Pos(Base.X, Base.Y);
    FAnim.LoopV(P, fTranslation, Base, V(Rnd(-50, 50), Rnd(25, 70)), Rnd(14, 30), Rnd(0, 6.28));
    FAnim.LoopF(P, fOpacity, 0.55, 0.45, Rnd(2, 6), Rnd(0, 6.28));
  end;
end;

{ ---------- garden eels: a colony in the open sand that ducks into its burrows ---------- }

procedure TOceanScene.BuildGardenEels(K: Integer);
const
  // x, base y, scale, colour (0 = spotted, 1 = orange)
  Spots: array [0 .. 6, 0 .. 3] of Single = ((1035, 952, 0.6, 0), (1090, 937, 0.53, 1), (1142, 965, 0.67, 0),
    (1196, 944, 0.56, 0), (1250, 960, 0.64, 1), (1306, 940, 0.52, 0), (1356, 970, 0.7, 0));
var
  I: Integer;
  X, Y, S, H: Single;
  Sec, Wrap, Po: TNode;
begin
  Sec := SecGroup(FGardenEels, K, NearPeriod);
  with FColonies[K] do
  begin
    SetLength(Eels, Length(Spots));
    X0 := Min(SecX(K, NearPeriod, 1035), SecX(K, NearPeriod, 1356));
    X1 := Max(SecX(K, NearPeriod, 1035), SecX(K, NearPeriod, 1356));
    Solo := Rnd(15, 30) * 1000;
    for I := 0 to High(Spots) do
    begin
      X := Spots[I, 0];
      Y := Spots[I, 1];
      S := Spots[I, 2];
      Sec.AddPoster('geel_hole').Scale(S * 1.2, S * 1.2).Pos(X - 24 * S, Y - 8.4 * S);
      // the eel is only drawn above its burrow, so it slides down into the sand
      Wrap := Sec.AddGroup;
      H := 240 * S;
      Wrap.SetClip(X - 70, Y - H - 70, 140, H + 70);
      Eels[I].Inner := Wrap.AddGroup;
      Po := Eels[I].Inner.AddPoster(IfThen(Spots[I, 3] = 0, 'geel_a', 'geel_b'));
      Po.Pivot(18, 240).Scale(S, S).Pos(X - 18, Y - 240);
      // they all lean into the same current, a little out of step
      FAnim.LoopF(Po, fRotation, 0.02, 0.06, Rnd(3.6, 4.2), I * 0.5);
      Eels[I].X := SecX(K, NearPeriod, X);
      Eels[I].H := H + 10;
      Eels[I].Anim := FAnim.New(1);
    end;
  end;
end;

procedure TOceanScene.MoveGeel(var E: TGeel; ToY, Duration, Delay: Single; Ease: TEase);
var
  Cur: Single;
begin
  Cur := E.Inner.Ty;
  E.Anim.Stop;
  E.Anim.ClearTracks;
  E.Anim.Duration := Duration;
  E.Anim.Delay := Delay;
  E.Anim.Ease := Ease;
  E.Anim.KeysV(E.Inner, fTranslation, [0, 1], [V(0, Cur), V(0, ToY)]);
  E.Anim.Start;
end;

{ something swimming close to the sand near the colony? X = where it is }
function TOceanScene.GeelThreat(const Col: TColony; out X: Single): Boolean;
var
  C: TLive;
  Big: Boolean;
  M0: Single;
begin
  for C in LiveCreatures(lNear) do
    if (C.Kind <> 'star') and (C.Kind <> 'seahorse') and (C.Kind <> 'clown') then
    begin
      Big := (C.Kind = 'shark') or (C.Kind = 'turtle') or (C.Kind = 'manta') or (C.Kind = 'dolphin');
      // big animals are noticed from further away; crabs only right at the colony
      M0 := 120;
      if Big then M0 := 260;
      if C.Kind = 'crab' then M0 := 60;
      if (C.X > Col.X0 - M0) and (C.X < Col.X1 + M0) and ((C.Y > 740) or (Big and (C.Y > 450))) then
      begin
        X := C.X;
        Exit(True);
      end;
    end;
  Result := False;
end;

procedure TOceanScene.UpdateGardenEels;
var
  Night, Threat: Boolean;
  Tx: Single;
  K, I: Integer;
begin
  if Off('geel') then Exit;
  // garden eels sleep inside their burrows at night
  Night := FDay < 0.2;
  for K := 0 to High(FColonies) do
    with FColonies[K] do
    begin
      Threat := (not Night) and GeelThreat(FColonies[K], Tx);
      if Night or Threat then
      begin
        if not Down then
        begin
          Down := True;
          for I := 0 to High(Eels) do
            if Night then
              MoveGeel(Eels[I], Eels[I].H, 1.5, Rnd(0, 3), eLinear)
            else
              // a quick wave of ducking, starting nearest the visitor
              MoveGeel(Eels[I], Eels[I].H, 0.3, Abs(Eels[I].X - Tx) / 1600, eLinear);
        end;
        UpAt := FNow + Rnd(3500, 6000);
      end
      else if Down and (FNow >= UpAt) then
      begin
        Down := False;
        for I := 0 to High(Eels) do MoveGeel(Eels[I], 0, Rnd(2.2, 3.4), Rnd(0, 2.5), eOutQuad);
        Solo := FNow + Rnd(15, 35) * 1000;
      end
      else if (not Down) and (FNow >= Solo) then
      begin
        // now and then one eel ducks on its own and slowly comes back up
        I := Random(Length(Eels));
        Eels[I].Anim.Stop;
        Eels[I].Anim.ClearTracks;
        Eels[I].Anim.Duration := 6;
        Eels[I].Anim.Delay := 0;
        Eels[I].Anim.Ease := eLinear;
        Eels[I].Anim.KeysV(Eels[I].Inner, fTranslation, [0, 0.05, 0.5, 1],
          [V(0, 0), V(0, Eels[I].H), V(0, Eels[I].H), V(0, 0)]);
        Eels[I].Anim.Start;
        Solo := FNow + Rnd(12, 30) * 1000;
      end;
    end;
end;

{ centre, scale and node of every creature currently placed in a layer (layer coordinates) }
function TOceanScene.LiveCreatures(Layer: TLayer): TArray<TLive>;
var
  Sl: TSlot;
  C: TCreature;
  Spec: TSpec;
  L: TLive;
begin
  Result := nil;
  for Sl in FSlots do
    if (Sl.Layer = Layer) and (Sl.Kind <> '') then
    begin
      Spec := FSpecs[Sl.Kind];
      for C in Sl.Nodes do
        if C.Root <> nil then
        begin
          L.Kind := Sl.Kind;
          L.X := C.Root.Tx + Spec.Cx;
          L.Y := C.Root.Ty + Spec.Cy;
          L.S := Abs(C.Root.Sx);
          L.Node := C;
          Result := Result + [L];
        end;
    end;
end;

{ ---------- fish scatter when a shark comes through ---------- }

procedure TOceanScene.UpdateScatter;
var
  Layer, L2: TLayer;
  Sl: TSlot;
  HasShark, Turn: Boolean;
  Live: TArray<TLive>;
  Sh, P: TLive;
  Sd, Away: Integer;
  Ahead: Single;
begin
  for Layer in [lFar, lMid, lNear] do
  begin
    HasShark := False;
    for Sl in FSlots do
      if (Sl.Layer = Layer) and (Sl.Kind = 'shark') then HasShark := True;
    if not HasShark then Continue;
    Live := LiveCreatures(Layer);
    for Sh in Live do
      if Sh.Kind = 'shark' then
      begin
        Sd := Sh.Node.Dir;
        for P in Live do
          if P.Node.Fleeable and (P.Kind <> 'puffer') then
          begin
            Ahead := (P.X - Sh.X) * Sd;
            if (Ahead > -250 * Sh.S) and (Ahead < 1100 * Sh.S) and (Abs(P.Y - Sh.Y) < 330 * Sh.S) then
            begin
              Away := 1;
              if P.Y < Sh.Y then Away := -1;
              if P.Y < 160 then Away := 1;
              if P.Y > 860 then Away := -1;
              // swimming towards the shark's mouth: turn round first
              Turn := (P.Node.Dir = -Sd) and (Ahead > 0);
              P.Node.Flee(Away, Turn);
            end;
          end;
      end;
  end;
  // the pufferfish puffs up when a shark in any layer is heading its way (nothing else sets it off). It starts
  // while the shark is still a good way off, so it swells in full view before the shark swims past (or over) it
  if FSlots[FPufferSlot].Kind = 'puffer' then
    for P in LiveCreatures(lMid) do
      if (P.Kind = 'puffer') and P.Node.Fleeable then
        for L2 in [lFar, lMid, lNear] do
          for Sh in LiveCreatures(L2) do
            if Sh.Kind = 'shark' then
            begin
              Ahead := (P.X - Sh.X) * Sh.Node.Dir;
              if (Ahead > 420 * Sh.S + 150) and (Ahead < 420 * Sh.S + 750) and (Abs(Sh.Y - P.Y) < 300) then
                P.Node.Flee(-1, False);
            end;
end;

{ ---------- full-moon nights: moonlight and coral spawning ---------- }

{ days from the nearest full moon (negative = before it), from the PC's clock }
function TOceanScene.MoonFromFull: Single;
const
  Syn = 29.530588853;
var
  Days, Age: Double;
begin
  Days := (DateTimeToUnix(Now, False) - 947182440) / 86400;
  Age := Days - Syn * Floor(Days / Syn);
  Result := Age - Syn / 2;
end;

procedure TOceanScene.BuildSpawning;
var
  I: Integer;
begin
  FAnim.LoopV(FMoonGlow, fScale, V(7, 3), V(0.35, 0.15), 7, 0);
  SetLength(FSpawnPool, 80 * FNearN);
  for I := 0 to High(FSpawnPool) do
  begin
    FSpawnPool[I].P := FSpawnG.AddPoster('spawn_dot');
    FSpawnPool[I].P.Opacity := 0;
    FSpawnPool[I].Anim := FAnim.New(1);
  end;
  FMoonCheckAt := 60000;
  FFromFull := MoonFromFull;
  SetMoon;
end;

{ moonlight strength: 1 at full moon, fading to 0 three days either side }
procedure TOceanScene.SetMoon;
begin
  FMoonK := MaxF(0, 1 - Abs(FFromFull) / 3);
  if FForceSpawn then FMoonK := 1;
end;

{ the corals of section K release a cloud of spawn }
procedure TOceanScene.ReleaseSpawn(K: Integer);
const
  // where the corals release their spawn (x from, x to, y from, y to): staghorns and the brain coral
  Src: array [0 .. 3, 0 .. 3] of Single = ((170, 470, 610, 760), (1325, 1590, 650, 770), (1050, 1300, 790, 830),
    (200, 430, 640, 740));
var
  S, N, I, J: Integer;
  X0, Y0, Dur, Delay, Rise, Drift, Ph, T, Sz, Dx: Single;
  Keys: array [0 .. 10] of Single;
  Vals: array [0 .. 10] of TVec2;
begin
  S := Random(Length(Src));
  // the rearranged sections have no first staghorn: their other staghorn and the brain coral spawn
  Dx := 0;
  if Layout(K).Alt then
  begin
    S := 1 + Random(2);
    if S = 1 then Dx := Layout(K).Stag2;
  end;
  N := Trunc(Rnd(18, 30));
  for I := 0 to High(FSpawnPool) do
    if (N > 0) and (FNow >= FSpawnPool[I].FreeAt) then
      with FSpawnPool[I] do
      begin
        Dec(N);
        X0 := SecX(K, NearPeriod, Rnd(Src[S, 0], Src[S, 1]) + Dx);
        Y0 := Rnd(Src[S, 2], Src[S, 3]);
        Dur := Rnd(16, 26);
        Delay := Rnd(0, 4);
        Rise := Rnd(550, 900);
        Drift := Rnd(-120, 120);
        Ph := Rnd(0, 6.28);
        for J := 0 to 10 do
        begin
          T := J / 10;
          Keys[J] := T;
          Vals[J] := V(X0 + Drift * T + 22 * Sin(T * 7 + Ph), Y0 - Rise * T);
        end;
        Sz := Rnd(0.55, 1.15);
        Anim.Stop;
        Anim.ClearTracks;
        P.Scale(Sz, Sz);
        P.Pos(Vals[0].X, Vals[0].Y);
        P.Opacity := 0;
        Anim.Duration := Dur;
        Anim.Delay := Delay;
        Anim.KeysV(P, fTranslation, Keys, Vals);
        Anim.KeysF(P, fOpacity, [0, 0.06, 0.6, 1], [0, Rnd(0.6, 0.95), 0.5, 0]);
        Anim.Start;
        FreeAt := FNow + (Dur + Delay) * 1000 + 300;
      end;
end;

procedure TOceanScene.UpdateSpawning;
var
  LateNight, Tonight: Boolean;
  K: Integer;
begin
  if FNow >= FMoonCheckAt then
  begin
    FMoonCheckAt := FNow + 60000;
    FFromFull := MoonFromFull;
    SetMoon;
  end;
  LateNight := (FHour >= 20.5) or (FHour < 3.5);
  // corals spawn on the nights just after the full moon
  Tonight := ((FFromFull >= -1) and (FFromFull <= 3)) or FForceSpawn;
  if Tonight and LateNight and (FDay < 0.2) and (not Off('spawn')) and (FNow >= FSpawnNext) then
  begin
    for K := 0 to FNearN - 1 do ReleaseSpawn(K);
    FSpawnNext := FNow + Rnd(4, 9) * 1000;
  end;
end;

{ ---------- day / night cycle (follows the PC's local clock) ---------- }

function TOceanScene.CurrentHour: Single;
var
  H: Double;
begin
  if FSet.Light = 'day' then Exit(12.5);
  if FSet.Light = 'sunset' then Exit(19.0);
  if FSet.Light = 'night' then Exit(23.0);
  if FSet.Light = 'cycle' then
    // a whole day every 20 minutes
    H := FCycleStart + (FNow - FCycleT0) / 50000
  else
    H := Frac(Now) * 24 + FTimeOffset;
  Result := H - 24 * Floor(H / 24);
end;

procedure TOceanScene.UpdateLight;
var
  H, Day, Warm, Mk, Lk: Single;
begin
  H := CurrentHour;
  FHour := H;
  // dawn 5:30-7:30, dusk 18:00-20:00
  if (H < 5.5) or (H >= 20) then
    Day := 0
  else if H < 7.5 then
    Day := Smoothstep((H - 5.5) / 2)
  else if H < 18 then
    Day := 1
  else
    Day := 1 - Smoothstep((H - 18) / 2);
  Warm := MaxF(0, 1 - Abs(H - 6.6) / 1.2) + MaxF(0, 1 - Abs(H - 19.0) / 1.2);
  FDay := Day;
  // around full moon the night is a little brighter and the moon glows through the surface
  Mk := FMoonK * (1 - Day);
  FNightShade.Opacity := 0.74 * (1 - Day) - 0.1 * Mk;
  FNightShade.Visible := Day < 0.995;
  FMoonGlow.Opacity := 0.85 * Mk;
  FMoonGlow.Visible := Mk > 0.01;
  FWarm.Opacity := 0.42 * Warm;
  FWarm.Visible := Warm > 0.005;
  FRays.Opacity := 0.12 + 0.88 * Day + 0.16 * Mk;
  FCaustics.Opacity := 0.08 + 0.92 * Day;
  FGlow.Opacity := 1 - Day;
  FGlow.Visible := Day < 0.995;
  // the diver's torch shows as it gets dark
  Lk := MaxF(0, 1 - Day * 2);
  FFarLight.Opacity := Lk;
  FFarLight.Visible := Lk > 0.005;
  FMidLight.Opacity := Lk;
  FMidLight.Visible := Lk > 0.005;
end;

{ ---------- clock / date overlay (hops between corners every few minutes to avoid screen burn-in) ---------- }

procedure TOceanScene.BuildClock;
const
  Sizes: array [0 .. 3] of Integer = (84, 84, 40, 40);
  Colors: array [0 .. 3] of Cardinal = ($000000, $FFFFFF, $000000, $E8F6FF);
var
  I: Integer;
begin
  for I := 0 to 3 do
  begin
    FLabels[I].Node := FClockGrp.AddPoster('');
    FLabels[I].Node.SetColor(Colors[I]);
    if not Odd(I) then FLabels[I].Node.Opacity := 0.6;   // the drop shadows
    FLabels[I].Size := Sizes[I];
    FLabels[I].Bold := I < 2;
  end;
  FClockGrp.Visible := False;
  FClockGrp.Opacity := 0.85;
  FClockOut := FAnim.New(1.2);
  FClockOut.KeysF(FClockGrp, fOpacity, [0, 1], [0.85, 0]);
  FClockIn := FAnim.New(1.2);
  FClockIn.KeysF(FClockGrp, fOpacity, [0, 1], [0, 0.85]);
end;

procedure TOceanScene.ApplyClock;
var
  Mode: string;
  ShowT, ShowD: Boolean;
  Dy: Single;
begin
  Mode := FSet.Clock;
  FClockOn := (Mode = 'time') or (Mode = 'date') or (Mode = 'both');
  FClockGrp.Visible := FClockOn;
  if not FClockOn then Exit;
  ShowT := (Mode = 'time') or (Mode = 'both');
  ShowD := (Mode = 'date') or (Mode = 'both');
  FLabels[0].Node.Visible := ShowT;
  FLabels[1].Node.Visible := ShowT;
  FLabels[2].Node.Visible := ShowD;
  FLabels[3].Node.Visible := ShowD;
  Dy := 96;
  if not ShowT then Dy := 0;
  FLabels[0].Y := 3;
  FLabels[1].Y := 0;
  FLabels[2].Y := Dy + 3;
  FLabels[3].Y := Dy;
  FClockText := '';
  FClockIdx := Random(4);
  UpdateClockText;
  PlaceClock(FClockIdx);
  FClockGrp.Opacity := 0.85;
  FClockPhase := '';
  FClockMoveAt := FNow + 150000;
end;

{ corners: 0 top left, 1 top right, 2 bottom left, 3 bottom right of the clock's area (the visible part of the
  reef, or the main screen when the reef spans several) }
procedure TOceanScene.PlaceClock(I: Integer);
var
  K: Integer;
  Right: Boolean;
  W, X0, Y0, X1, Y1: Single;
begin
  FClockIdx := I;
  X0 := FVX0;
  Y0 := FVY0;
  X1 := FVX1;
  Y1 := FVY1;
  if FHasClockArea then
  begin
    X0 := MaxF(X0, (FClockArea.Left - FView.E) / FViewScale);
    Y0 := MaxF(Y0, (FClockArea.Top - FView.F) / FViewScale);
    X1 := Min(X1, (FClockArea.Right - FView.E) / FViewScale);
    Y1 := Min(Y1, (FClockArea.Bottom - FView.F) / FViewScale);
  end;
  Right := Odd(I);
  if Right then FClockGrp.Tx := X1 - 80 else FClockGrp.Tx := X0 + 80;
  if I < 2 then FClockGrp.Ty := Y0 + 50 else FClockGrp.Ty := Y1 - 220;
  for K := 0 to 3 do
    with FLabels[K] do
    begin
      W := Node.W;
      // the shadows sit 3 pixels right and down
      if Right then Node.Tx := -W else Node.Tx := 0;
      if not Odd(K) then Node.Tx := Node.Tx + 3;
      Node.Ty := Y;
    end;
end;

procedure TOceanScene.SetLabel(Index: Integer; const Text: string);
begin
  with FLabels[Index] do
  begin
    Node.Tex := nil;
    FreeAndNil(Tex);
    // drawn at the screen's own resolution so the text stays sharp on any display
    Tex := Textures.MakeText(Text, 'Segoe UI', Max(8, Round(Size * FViewScale)), Bold);
    Node.Tex := Tex;
    Node.W := Tex.W / FViewScale;
    Node.H := Tex.H / FViewScale;
  end;
end;

procedure TOceanScene.UpdateClockText;
const
  Months: array [1 .. 12] of string = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December');
  Days: array [1 .. 7] of string = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
var
  T: TDateTime;
  H, H12: Integer;
  AmPm, TimeText, DateText: string;
begin
  T := Now;
  H := HourOf(T);
  AmPm := 'AM';
  if H >= 12 then AmPm := 'PM';
  H12 := H mod 12;
  if H12 = 0 then H12 := 12;
  TimeText := Format('%d:%.2d %s', [H12, MinuteOf(T), AmPm]);
  DateText := Format('%s, %s %d', [Days[DayOfWeek(T)], Months[MonthOf(T)], DayOf(T)]);
  if TimeText + DateText <> FClockText then
  begin
    FClockText := TimeText + DateText;
    SetLabel(0, TimeText);
    SetLabel(1, TimeText);
    SetLabel(2, DateText);
    SetLabel(3, DateText);
    PlaceClock(FClockIdx);
  end;
end;

procedure TOceanScene.TickClock;
begin
  if not FClockOn then Exit;
  UpdateClockText;
  if (FClockPhase = '') and (FNow >= FClockMoveAt) then
  begin
    FClockOut.Start;
    FClockPhase := 'out';
    FClockMoveAt := FNow + 1300;
  end
  else if (FClockPhase = 'out') and (FNow >= FClockMoveAt) then
  begin
    PlaceClock((FClockIdx + 1 + Random(3)) mod 4);
    FClockIn.Start;
    FClockPhase := '';
    FClockMoveAt := FNow + 150000;
  end;
end;

{ ---------- fishing hook: a fish always steals the bait ---------- }

procedure TOceanScene.BuildFishing;
var
  Inner, Line: TNode;
begin
  FHookGroup := FFishing.AddGroup('hookGroup');
  FHookGroup.Visible := False;
  FHookGroup.Pivot(24, -1250);
  Inner := FHookGroup.AddGroup;
  Inner.Scale(0.8, 0.8);
  Line := Inner.AddRect(2, 1600, $DDE8F0);
  Line.Pos(29, -1597);
  Line.Opacity := 0.55;
  Inner.AddPoster('hook');
  FBait := Inner.AddPoster('bait');
  FAnim.LoopF(FHookGroup, fRotation, 0, 0.012, 7, 0);
  FThief := TCreature.Create(FAnim, FSpecs, FFishing);
  FHookAnim := FAnim.New(1);
  FFishState := 'idle';
  FFishNext := Rnd(50, 100) * 1000;
end;

procedure TOceanScene.MoveHook(const Keys: array of Single; const Vals: array of TVec2; Duration: Single; Ease: TEase);
begin
  FHookAnim.Stop;
  FHookAnim.ClearTracks;
  FHookAnim.Duration := Duration;
  FHookAnim.Ease := Ease;
  FHookAnim.KeysV(FHookGroup, fTranslation, Keys, Vals);
  FHookAnim.Start;
end;

procedure TOceanScene.UpdateFishing;
begin
  if (FBiteAt > 0) and (FNow >= FBiteAt) then
  begin
    FBiteAt := 0;
    OnBite;
  end;
  if (FFishState = 'idle') and (FNow >= FFishNext) then
    StartFishing
  else if (FFishState = 'reel') and (FNow >= FFishNext) then
  begin
    MoveHook([0, 1], [FHookPos, V(FHookPos.X, -260)], 4.5, eInQuad);
    FFishState := 'up';
    FFishNext := FNow + 5000;
  end
  else if (FFishState = 'up') and (FNow >= FFishNext) then
  begin
    FHookGroup.Visible := False;
    FFishState := 'idle';
    FFishNext := FNow + Rnd(120, 300) * 1000;
  end;
end;

procedure TOceanScene.StartFishing;
var
  Thieves: TArray<string>;
  K: string;
  Hx, Hy, Duration: Single;
  C: TCfg;
begin
  for K in Strs(['tang', 'ytang', 'angel', 'lionfish', 'tang']) do
    if not Off(K) then Thieves := Thieves + [K];
  if Off('hook') or (Length(Thieves) = 0) then
  begin
    FFishNext := FNow + 30000;
    Exit;
  end;
  Hx := Rnd(450, FW - 520);
  Hy := Rnd(380, 600);
  FHookPos := V(Hx, Hy);
  FBait.Visible := True;
  FHookGroup.Pos(Hx, -260);
  FHookGroup.Visible := True;
  MoveHook([0, 1], [V(Hx, -260), V(Hx, Hy)], 6, eOutQuad);
  // the thief comes from the nearer edge, so on a wide reef the wait is not long
  Duration := Rnd(15, 19);
  Inc(FUid);
  C := Default(TCfg);
  C.Kind := Thieves[Random(Length(Thieves))];
  C.Uid := FUid;
  C.Depth := 0.74;
  C.Dir := IfThen(Hx > FW / 2, -1, 1);
  C.Amp := AmpNear;
  C.WorldW := FW;
  C.Mode := mSteal;
  C.HookX := Hx + 24 * 0.8;
  C.HookY := Hy + 90 * 0.8;
  C.Duration := Duration * MaxF(1, FW / 1920 / 2);
  C.Delay := 7;
  C.X := Hx;
  C.Y := Hy;
  FThief.Spawn(C);
  // the fish reaches the bait at 68% of its swim
  FBiteAt := FNow + (7 + C.Duration * 0.68) * 1000;
  FFishState := 'fishing';
end;

{ the fish grabs the worm: bait gone, the hook jerks, then it's reeled back up }
procedure TOceanScene.OnBite;
var
  P: TVec2;
begin
  FBait.Visible := False;
  P := FHookPos;
  MoveHook([0, 0.2, 0.45, 0.7, 1], [P, V(P.X + 10, P.Y - 16), V(P.X - 8, P.Y + 6), V(P.X + 4, P.Y - 4), P], 1.0, eLinear);
  FFishState := 'reel';
  FFishNext := FNow + 3000;
end;

{ "xmas" from 1 to 26 December (Scuba Steve wears a Santa hat), otherwise "" }
function TOceanScene.CurrentSeason: string;
begin
  if (MonthOf(Now) = 12) and (DayOf(Now) <= 26) then Result := 'xmas' else Result := '';
end;

{ ---------- creatures ---------- }

function TOceanScene.NewSlot(Layer: TLayer; Amp: Single; const Kinds: array of string; DMin, DMax, YMin, YMax, GapMin,
  GapMax: Single): TSlot;
begin
  Result := TSlot.Create;
  Result.Layer := Layer;
  Result.Amp := Amp;
  Result.Kinds := Strs(Kinds);
  Result.DMin := DMin;
  Result.DMax := DMax;
  Result.YMin := YMin;
  Result.YMax := YMax;
  Result.GapMin := GapMin;
  Result.GapMax := GapMax;
  Result.Mode := mCross;
  Result.Pod := 1;
end;

procedure TOceanScene.AddSlot(Sl: TSlot);
var
  K: Integer;
  C: TCreature;
begin
  SetLength(Sl.Nodes, Sl.Pod);
  for K := 0 to Sl.Pod - 1 do
  begin
    C := TCreature.Create(FAnim, FSpecs, FLayers[Sl.Layer]);
    C.Slot := FSlots.Count;
    C.OnDone := CreatureDone;
    FCreatures.Add(C);
    Sl.Nodes[K] := C;
  end;
  FSlots.Add(Sl);
end;

procedure TOceanScene.AddLayer(Layer: TLayer; Amp: Single; Count: Integer; const Kinds, NightKinds: array of string;
  DMin, DMax, YMin, YMax: Single);
const
  // the animal count setting keeps every third slot (a few), two in three (some) or all (lots),
  // spread through the depth range
  DensOf: array [0 .. 2] of Integer = (0, 2, 1);
var
  I: Integer;
  Sl: TSlot;
begin
  // a wider reef holds more fish
  Count := Max(Count, Round(Count * FW / 1920));
  // each slot gets its own slice of the depth range, so nearer slots draw on top
  for I := 0 to Count - 1 do
  begin
    Sl := NewSlot(Layer, Amp, Kinds, DMin + (DMax - DMin) * I / Count, DMin + (DMax - DMin) * (I + 1) / Count,
      YMin, YMax, 1, 9);
    Sl.NightKinds := Strs(NightKinds);
    Sl.Rest := 0.45;
    Sl.Dens := DensOf[I mod 3];
    AddSlot(Sl);
  end;
end;

procedure TOceanScene.BuildSlots;
var
  Sl: TSlot;
  I, K: Integer;
  X: Single;
  Tw: TTwin;

  function First(S: TSlot; Seconds: Single): TSlot;
  begin
    S.HasFirst := True;
    S.First := Seconds;
    Result := S;
  end;

  procedure Twin(const Kind, LightKind: string; Layer: TNode);
  begin
    Tw.Kind := LightKind;
    Tw.Node := TCreature.Create(FAnim, FSpecs, Layer);
    FCreatures.Add(Tw.Node);
    FTwins.Add(Kind, Tw);
  end;

  procedure Jelly(DMin, DMax, GapMin, GapMax: Single; NightOnly: Boolean);
  begin
    Sl := NewSlot(lJelly, AmpJelly, ['jelly'], DMin, DMax, 0, 0, GapMin, GapMax);
    Sl.Mode := mRise;
    Sl.NightOnly := NightOnly;
    if NightOnly then Sl.Dens := 1;
    AddSlot(Sl);
  end;

  procedure Resident(const Kind: string; Mode: TMode; Depth, HomeX, HomeY, Range, Period: Single);
  begin
    Sl := NewSlot(lNear, AmpNear, [Kind], Depth, Depth, 0, 0, 0, 0);
    Sl.Mode := Mode;
    Sl.Home := V(HomeX, HomeY);
    Sl.HasRange := True;
    Sl.Range := Range;
    Sl.Period := Period;
    AddSlot(Sl);
  end;

begin
  // rare distant whale, behind the far reef
  AddSlot(First(NewSlot(lFarBack, AmpFar, ['whale'], 0.08, 0.14, 220, 420, 150, 260), 12));

  AddLayer(lFar, AmpFar, 6, ['tang', 'ytang', 'angel', 'school', 'school', 'shark', 'turtle', 'manta', 'lionfish'],
    ['shark', 'school', 'turtle', 'manta', 'shark'], 0.06, 0.32, 110, 680);

  // jellyfish: more of them at night
  for K := 1 to FWide do
  begin
    Jelly(0.2, 0.3, 10, 40, False);
    Jelly(0.4, 0.5, 20, 60, False);
    Jelly(0.3, 0.45, 5, 25, True);
    Jelly(0.5, 0.6, 5, 25, True);
  end;

  // a pod of dolphins racing past near the surface (daytime only)
  Sl := First(NewSlot(lMid, AmpMid, ['dolphin'], 0.5, 0.64, 150, 320, 90, 200), 25);
  Sl.Pod := 3;
  Sl.DayOnly := True;
  AddSlot(Sl);

  AddLayer(lMid, AmpMid, 7, ['tang', 'ytang', 'angel', 'school', 'school', 'shark', 'turtle', 'manta', 'tang', 'angel',
    'lionfish', 'octopus'], ['shark', 'octopus', 'lionfish', 'turtle', 'school', 'octopus'], 0.38, 0.66, 120, 760);
  AddLayer(lNear, AmpNear, 3, ['tang', 'ytang', 'angel', 'school', 'tang', 'ytang', 'angel', 'lionfish', 'octopus'],
    ['octopus', 'lionfish', 'tang', 'lionfish'], 0.74, 0.92, 110, 760);

  // seahorses near the corals of every section: they drift slowly around their home in a loop
  // (never turning: a flipped seahorse looks wrong)
  for K := 0 to FNearN - 1 do
  begin
    // one by the rock, one in the staghorn coral
    X := SecX(K, NearPeriod, 1790 + Layout(K).Rock);
    if X < FW + 100 then Resident('seahorse', mBob, 0.8, X, 690, 55, 36);
    if Layout(K).Alt then X := SecX(K, NearPeriod, 1520) else X := SecX(K, NearPeriod, 330);
    if X < FW + 100 then Resident('seahorse', mBob, 0.75, X, 735, 70, 42);
  end;

  // glowing twins, drawn above the night shade: the diver's torch, the submarine's headlight, the anglerfish's lure
  Twin('diver', 'diverlight', FFarLight);
  Twin('sub', 'sublight', FFarLight);
  Twin('angler', 'anglerlight', FMidLight);

  // a scuba diver far in the background, once in a while
  FDiverSlot := FSlots.Count;
  AddSlot(First(NewSlot(lFar, AmpFar, ['diver'], 0.18, 0.24, 260, 520, 180, 360), 70));
  // Captain Greg's yellow submarine, now and then: tiny and far behind everything else (behind the far reef too)
  AddSlot(First(NewSlot(lFarBack, AmpFar, ['sub'], 0.03, 0.06, 180, 400, 300, 600), 200));
  // a rare pufferfish: it only puffs up (and floats away) when a shark comes close
  FPufferSlot := FSlots.Count;
  AddSlot(First(NewSlot(lMid, AmpMid, ['puffer'], 0.56, 0.62, 300, 600, 300, 600), 130));
  // an anglerfish prowling in the dark (night only)
  Sl := First(NewSlot(lMid, AmpMid, ['angler'], 0.5, 0.58, 250, 640, 90, 240), 40);
  Sl.NightOnly := True;
  AddSlot(Sl);

  // a clownfish pair lives at every anemone
  for K := 0 to FNearN - 1 do
    for I := 0 to 1 do
    begin
      X := SecX(K, NearPeriod, 890 - I * 40 + Layout(K).Anemone);
      if X < FW + 100 then Resident('clown', mHover, 0.62 + I * 0.05, X, 705 - I * 75, 110 + I * 60, 0);
    end;

  // crabs and sea stars crossing the sand in front
  for K := 1 to FWide do
    AddSlot(NewSlot(lNear, AmpNear, ['crab', 'crab', 'star'], 0.85, 0.9, 985, 1030, 15, 45));

  // rare big close-up pass right in front of the camera
  FCloseSlot := FSlots.Count;
  Sl := First(NewSlot(lNear, AmpNear, ['shark', 'turtle', 'manta', 'shark', 'dolphin'], 0.9, 1.0, 200, 560, 70, 150), 35);
  Sl.NightKinds := Strs(['shark', 'octopus', 'shark']);
  AddSlot(Sl);

  for I := 0 to FSlots.Count - 1 do
    if FSlots[I].HasFirst then
      FSlots[I].Due := FSlots[I].First * 1000
    else
      SpawnSlot(I, True);
end;

procedure TOceanScene.SpawnSlot(I: Integer; Initial: Boolean);
var
  Sl: TSlot;
  Night: Boolean;
  Kinds, Allowed: TArray<string>;
  K, Kind: string;
  Dir, N: Integer;
  Y: Single;
  C, Lc: TCfg;
  Tw: TTwin;
  HasTwin: Boolean;
begin
  Sl := FSlots[I];
  // slots that the "how many animals" setting leaves empty
  if Sl.Dens > FDensity then
  begin
    Sl.Kind := '';
    Sl.Due := FNow + 60000;
    Exit;
  end;
  Night := FDay < 0.35;
  if (Night and Sl.DayOnly) or ((not Night) and Sl.NightOnly) then
  begin
    Sl.Due := FNow + 30000;
    Exit;
  end;
  if Night and (Sl.Rest > 0) and (Random < Sl.Rest) then
  begin
    // reef fish shelter at night: this slot stays empty for a while
    Sl.Due := FNow + Rnd(10, 30) * 1000;
    Exit;
  end;
  Kinds := Sl.Kinds;
  if Night and (Length(Sl.NightKinds) > 0) then Kinds := Sl.NightKinds;
  // only animals that are switched on in settings
  for K in Kinds do
    if not Off(K) then Allowed := Allowed + [K];
  if Length(Allowed) = 0 then
  begin
    Sl.Kind := '';
    Sl.Due := FNow + 5000;
    Exit;
  end;
  Kind := Allowed[Random(Length(Allowed))];
  if not FSeasonFixed then FSeason := CurrentSeason;
  if Sl.ForceKind <> '' then
  begin
    Kind := Sl.ForceKind;
    Sl.ForceKind := '';
  end;
  Sl.Kind := Kind;
  Dir := IfThen(Random < 0.5, -1, 1);
  Y := Rnd(Sl.YMin, Sl.YMax);
  if (Kind = 'shark') or (Kind = 'turtle') or (Kind = 'manta') or (Kind = 'whale') or (Kind = 'dolphin') then
    Y := Rnd(Sl.YMin + 40, Sl.YMin + (Sl.YMax - Sl.YMin) * 0.7);
  Sl.Pending := Length(Sl.Nodes);
  HasTwin := FTwins.TryGetValue(Kind, Tw);
  for N := 0 to High(Sl.Nodes) do
  begin
    Inc(FUid);
    C := Default(TCfg);
    C.Kind := Kind;
    C.Uid := FUid;
    C.Depth := Rnd(Sl.DMin, Sl.DMax);
    C.Dir := Dir;
    C.Amp := Sl.Amp;
    C.WorldW := FW;
    C.Y := Y + N * Rnd(-55, 55);
    C.X := Rnd(150, FW - 150);
    C.Mode := Sl.Mode;
    C.Initial := Initial;
    C.Delay := N * Rnd(0.4, 0.9);
    C.Home := Sl.Home;
    C.HasRange := Sl.HasRange;
    C.Range := Sl.Range;
    C.Period := Sl.Period;
    C.YMin := Sl.YMin;
    C.YMax := Sl.YMax;
    C.Season := FSeason;
    C.Night := FDay < 0.6;
    if HasTwin then
    begin
      // its light is a twin swimming the very same path above the night shade
      C.Fixed := True;
      C.SizeK := Rnd(0.88, 1.12);
      C.SpeedK := Rnd(0.85, 1.15);
      C.Phase := Rnd(0, 6.28);
      C.Dy := Rnd(-90, 90);
      C.Wave := Rnd(600, 1000);
      C.Ph := Rnd(0, 6.28);
      C.Sx0 := Rnd(100, FW - 220);
      if FDay < 0.6 then
      begin
        Inc(FUid);
        Lc := C;
        Lc.Kind := Tw.Kind;
        Lc.Uid := FUid;
        Tw.Node.Spawn(Lc);
      end
      else
        Tw.Node.Despawn;
    end;
    Sl.Nodes[N].Spawn(C);
  end;
end;

procedure TOceanScene.CreatureDone(C: TCreature);
var
  Sl: TSlot;
begin
  if C.Slot < 0 then Exit;
  Sl := FSlots[C.Slot];
  Dec(Sl.Pending);
  if Sl.Pending <= 0 then Sl.Due := FNow + Rnd(Sl.GapMin, Sl.GapMax) * 1000;
end;

{ command-line test options: bring on an event straight away instead of waiting for it }
procedure TOceanScene.ApplyTestOptions;
var
  Sl: TSlot;
begin
  if FSet.Show <> '' then
  begin
    for Sl in FSlots do
      if (Length(Sl.Kinds) = 1) and (Sl.Kinds[0] = FSet.Show) then Sl.Due := 1000;
    // the pufferfish test also sends a big shark once the puffer is well on screen, so it puffs up
    if FSet.Show = 'puffer' then
    begin
      FSlots[FCloseSlot].ForceKind := 'shark';
      FSlots[FCloseSlot].Due := 16000;
    end;
  end;
  if FSet.Shark then
  begin
    FSlots[FCloseSlot].ForceKind := 'shark';
    FSlots[FCloseSlot].Due := 2000;
  end;
  if FSet.Diver then FSlots[FDiverSlot].Due := 1000;
  if FSet.Fish then FFishNext := 1500;
  if FSet.Shrimp then FShrimpNext := 1000;
end;

{ twice a second: the slower decisions }
procedure TOceanScene.Tick;
var
  I: Integer;
begin
  UpdateLight;
  TickClock;
  UpdateFishing;
  UpdateShrimp;
  UpdateGardenEels;
  UpdateScatter;
  UpdateSpawning;
  for I := 0 to FSlots.Count - 1 do
    if (FSlots[I].Due > 0) and (FNow >= FSlots[I].Due) then
    begin
      FSlots[I].Due := 0;
      SpawnSlot(I, False);
    end;
end;

procedure TOceanScene.Advance(Dt: Single);
var
  I: Integer;
  T: Single;
begin
  FNow := FNow + Dt * 1000;
  // camera sway: a slow loop every 46 seconds
  T := Frac(FNow / 46000);
  for I := 0 to High(FCams) do
    FCams[I].Pos(FCamAmp[I] * Sin(T * 2 * Pi), FCamAmp[I] * 0.18 * Sin(T * 4 * Pi + 0.5));
  FAnim.Update(Dt);
  FTickAcc := FTickAcc + Dt;
  if FTickAcc >= 0.5 then
  begin
    FTickAcc := FTickAcc - 0.5;
    if FTickAcc > 0.5 then FTickAcc := 0;
    Tick;
  end;
end;

procedure TOceanScene.Render(OriginX, OriginY: Integer);
begin
  glViewport(OriginX, OriginY, FWinW, FWinH);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, FWinW, FWinH, 0, -1, 1);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  // clear this view only
  glEnable(GL_SCISSOR_TEST);
  glScissor(OriginX, OriginY, FWinW, FWinH);
  glClearColor($0A / 255, $4A / 255, $78 / 255, 1);
  glClear(GL_COLOR_BUFFER_BIT);
  DrawTree(FRoot, FView, FWinH, OriginX, OriginY);
end;

end.
