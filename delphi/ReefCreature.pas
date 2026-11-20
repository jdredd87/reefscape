unit ReefCreature;

{ One animal (or school, or pod member): builds its parts and runs its swimming animation.
  A port of components/Creature.brs. }

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, ReefEngine, ReefSpecs;

type
  TMode = (mCross, mHover, mRise, mBob, mSteal, mFlee, mPuff);

  TCfg = record
    Kind, Season: string;
    Uid, Dir: Integer;               // Dir: 1 = swimming right, -1 = left
    Depth: Single;                   // 0 far .. 1 near
    Amp: Single;                     // the layer's parallax sway
    WorldW: Single;                  // width of the reef in design units (1920 on a 16:9 screen)
    X, Y, Delay, Range, Period, YMin, YMax: Single;
    Mode: TMode;
    Initial, Night, HasRange, Fixed, Turned: Boolean;
    Home, StartPos: TVec2;
    SizeK, SpeedK: Single;           // 0 = not chosen yet
    // fixed values let two creatures swim the very same path: an animal and its light
    Phase, Dy, Wave, Ph, Sx0: Single;
    FleeY, HookX, HookY, Duration: Single;
  end;

  TCreature = class
  private
    FAnimator: TAnimator;
    FSpecs: TSpecs;
    FAnims: TList<TAnim>;
    FSwim: TAnim;
    FParts: TDictionary<string, TNode>;
    FInner: TNode;
    procedure ClearAll;
    procedure Keep(A: TAnim);
    procedure Watch(A: TAnim);
    procedure BuildParts(Parent: TNode; const Spec: TSpec; const Prefix: string; Depth: Single; ADir: Integer;
      Phase, SpeedK: Single);
    procedure BuildSchool(const Spec: TSpec; Tint: Cardinal; ADir: Integer; Spread: Single);
    procedure AddExhale(const Spec: TSpec; ADir: Integer; Tint: Cardinal);
    procedure StartCross(const Spec: TSpec; S: Single; ADir: Integer; Persp, SpeedK: Single);
    procedure StartRise(const Spec: TSpec; S, Persp, SpeedK: Single);
    procedure StartHover(const Spec: TSpec; SY, S: Single);
    procedure StartBob(const Spec: TSpec);
    procedure StartSteal(const Spec: TSpec; S: Single; ADir: Integer);
    procedure StartFlee(const Spec: TSpec; S, Sy: Single; ADir: Integer; Persp, SpeedK: Single);
    procedure PuffUp(const Spec: TSpec);
  public
    Node: TNode;                     // this creature's place in its layer
    Root: TNode;                     // nil while nothing is spawned
    Cfg: TCfg;
    Dir: Integer;
    Fleeable: Boolean;
    Slot: Integer;
    OnDone: TProc<TCreature>;
    constructor Create(AAnimator: TAnimator; ASpecs: TSpecs; ALayer: TNode);
    destructor Destroy; override;
    procedure Spawn(const ACfg: TCfg);
    procedure Despawn;
    { a shark is coming: dart away (AwayY = -1 up / 1 down; Turn = turn round first) }
    function Flee(AwayY: Integer; Turn: Boolean): Boolean;
  end;

implementation

const
  TwoPi = 6.2831853;

constructor TCreature.Create(AAnimator: TAnimator; ASpecs: TSpecs; ALayer: TNode);
begin
  FAnimator := AAnimator;
  FSpecs := ASpecs;
  FAnims := TList<TAnim>.Create;
  FParts := TDictionary<string, TNode>.Create;
  Node := ALayer.AddGroup;
  Slot := -1;
end;

destructor TCreature.Destroy;
begin
  FAnims.Free;
  FParts.Free;
  inherited;
end;

procedure TCreature.ClearAll;
var
  A: TAnim;
begin
  for A in FAnims do FAnimator.Kill(A);
  FAnims.Clear;
  FSwim := nil;
  Root := nil;
  FInner := nil;
  FParts.Clear;
  Fleeable := False;
  Node.Clear;
end;

procedure TCreature.Despawn;
begin
  ClearAll;
end;

procedure TCreature.Keep(A: TAnim);
begin
  FAnims.Add(A);
end;

{ the swimming animation: when it ends the creature reports that it is done }
procedure TCreature.Watch(A: TAnim);
begin
  FSwim := A;
  FAnims.Add(A);
  A.OnDone :=
    procedure
    begin
      FSwim := nil;
      // finished: it waits off screen until its slot reuses it, so it must not flee any more
      // (it would race back across the screen and vanish when the slot spawns the next animal)
      Fleeable := False;
      if Assigned(OnDone) then OnDone(Self);
    end;
  A.Start;
end;

function TCreature.Flee(AwayY: Integer; Turn: Boolean): Boolean;
var
  Spec: TSpec;
  X: Single;
  C: TCfg;
begin
  if (not Fleeable) or (Root = nil) then Exit(False);
  Spec := FSpecs[Cfg.Kind];
  // only from on screen (or just at its edge): a fish waiting off screen must not race back in
  X := Root.Tx + Spec.Cx;
  if (X < -60) or (X > Cfg.WorldW + 60) then Exit(False);
  if Spec.Puff > 0 then
  begin
    // a pufferfish only puffs up well inside the screen, where the whole show can be seen
    if (X < 260) or (X > Cfg.WorldW - 260) then Exit(False);
    PuffUp(Spec);
    Exit(True);
  end;
  C := Cfg;
  C.Mode := mFlee;
  C.Delay := 0;
  C.Initial := False;
  C.FleeY := AwayY;
  C.Turned := Turn;
  if Turn then C.Dir := -Cfg.Dir;
  C.StartPos := V(Root.Tx + Spec.Cx, Root.Ty + Spec.Cy);
  Spawn(C);
  Result := True;
end;

procedure TCreature.Spawn(const ACfg: TCfg);
var
  C: TCfg;
  Spec: TSpec;
  Persp, S, Sy, SpeedK, AnimK, Phase, Period, A: Single;
  D, MoveDir: Integer;
  Tint: Cardinal;
  GR, GL: TNode;
begin
  C := ACfg;
  if C.WorldW < 1920 then C.WorldW := 1920;
  ClearAll;
  Spec := FSpecs[C.Kind];
  Persp := 0.22 + 0.78 * C.Depth;
  // keep the same size and speed if this is the same animal starting to flee
  if C.SizeK = 0 then C.SizeK := Rnd(0.88, 1.12);
  if C.SpeedK = 0 then C.SpeedK := Rnd(0.85, 1.15);
  S := Spec.Scale * Persp * C.SizeK;
  D := C.Dir;
  if Spec.NoFlip then D := 1;
  Sy := Spec.Sy;
  Tint := TintFor(C.Depth);
  SpeedK := C.SpeedK;
  Phase := Rnd(0, 6.28);
  if C.Fixed then Phase := C.Phase;
  Cfg := C;
  Dir := D;
  // fleeing animals beat their tails much faster
  AnimK := SpeedK;
  if C.Mode = mFlee then AnimK := SpeedK * 2.6;

  Root := Node.AddGroup;
  Root.Pivot(Spec.Cx, Spec.Cy).Scale(S, S * Sy);
  FInner := Root.AddGroup;
  FInner.Pivot(Spec.Cx, Spec.Cy);

  if C.Mode = mHover then
  begin
    // both facings are built; the hover animation cross-fades between them at each turn
    GR := FInner.AddGroup;
    GL := FInner.AddGroup;
    GL.Opacity := 0;
    FParts.Add('gR', GR);
    FParts.Add('gL', GL);
    BuildParts(GR, Spec, 'R', C.Depth, 1, Phase, SpeedK);
    BuildParts(GL, Spec, 'L', C.Depth, -1, Phase, SpeedK);
  end
  else if Spec.School > 0 then
    BuildSchool(Spec, Tint, D, IfThen(C.Mode = mFlee, 1.7, 1.0))
  else
    BuildParts(FInner, Spec, '', C.Depth, D, Phase, AnimK);

  if Spec.Sway <> 0 then Keep(FAnimator.LoopF(FInner, fRotation, 0, Spec.Sway, Spec.SwayPeriod / AnimK, Phase + 1.6));
  if Spec.Flap <> 0 then Keep(FAnimator.LoopV(FInner, fScale, V(1, 0.8), V(0, 0.2), Spec.Flap, Phase));
  if Spec.HasExhale then AddExhale(Spec, D, Tint);
  if Spec.Hop <> 0 then Keep(FAnimator.LoopV(FInner, fTranslation, V(0, 0), V(0, -4), Spec.Hop, Phase));
  // crawlers that may go either way (NoFlip only fixes the image), moving in surges: speed swings
  // between 0.2x and 1.8x once per stride of Spec.Crawl seconds instead of a steady glide
  MoveDir := D;
  if Spec.Crawl <> 0 then
  begin
    MoveDir := C.Dir;
    Period := Spec.Crawl / SpeedK;
    A := 0.8 * (Spec.Speed * Persp * SpeedK) * Period / TwoPi / S;
    Keep(FAnimator.LoopV(FInner, fTranslation, V(0, 0), V(A * MoveDir, 0), Period, Phase));
  end;

  case C.Mode of
    mHover: StartHover(Spec, S * Sy, S);
    mRise: StartRise(Spec, S, Persp, SpeedK);
    mBob: StartBob(Spec);
    mSteal: StartSteal(Spec, S, D);
    mFlee: StartFlee(Spec, S, Sy, D, Persp, SpeedK);
  else
    StartCross(Spec, S, MoveDir, Persp, SpeedK);
    if Spec.Prey then Fleeable := True;
  end;
end;

{ Adds the creature's posters. Facing left uses the pre-mirrored "_l" images, with positions and pivots
  mirrored around Cx. }
procedure TCreature.BuildParts(Parent: TNode; const Spec: TSpec; const Prefix: string; Depth: Single; ADir: Integer;
  Phase, SpeedK: Single);
var
  Part: TPart;
  X, Px: Single;
  Po: TNode;
  Suffix: string;
begin
  Suffix := '';
  if ADir = -1 then Suffix := '_l';
  for Part in Spec.Parts do
  begin
    // seasonal parts (Scuba Steve's Santa hat) and night parts (his torch arm) are not always drawn
    if (Part.Season <> '') and (Part.Season <> Cfg.Season) then Continue;
    if Part.Night and not Cfg.Night then Continue;
    X := Part.X;
    Px := Part.Px;
    if ADir = -1 then
    begin
      X := 2 * Spec.Cx - Part.X - Part.W;
      if Part.HasPivot then Px := Part.W - Part.Px;
    end;
    if Part.Sym then Po := Parent.AddPoster(Part.Uri) else Po := Parent.AddPoster(Part.Uri + Suffix);
    FParts.AddOrSetValue(Prefix + Part.Id, Po);
    Po.Pos(X, Part.Y);
    // light (the torch beam, the lure) keeps its own colour
    if Part.Light then Po.SetColor($FFFFFF) else Po.SetColor(TintFor(Depth, Part.Dark));
    if Part.HasPivot then Po.Pivot(Px, Part.Py);
    Po.Rot := Part.Rot;
    Po.Opacity := Part.Op;
    // images stored at reduced size (Part.H = full height) are drawn at full size
    if Part.H <> 0 then Po.Size(Part.W, Part.H);
    case Part.Anim of
      paRot:
        begin
          // mirrored parts swing the mirrored way, so a turning fish's two facings match at the swap
          Keep(FAnimator.LoopF(Po, fRotation, Part.Rot, Part.Amp * ADir, Part.Period / SpeedK, Phase + Part.Po));
          // rotating parts can also stretch (a sea star's arm reaching and pulling in)
          if Part.HasSamp then
            Keep(FAnimator.LoopV(Po, fScale, V(1, 1), Part.Samp, Part.Period / SpeedK, Phase + Part.Po + Part.Sph));
        end;
      paScale:
        Keep(FAnimator.LoopV(Po, fScale, V(1, 1), Part.Samp, Part.Period, Phase + Part.Po));
    end;
  end;
end;

procedure TCreature.BuildSchool(const Spec: TSpec; Tint: Cardinal; ADir: Integer; Spread: Single);
var
  I: Integer;
  Fx, Fy: Single;
  Po: TNode;
  Img: string;
begin
  Img := 'school_fish';
  if ADir = -1 then Img := 'school_fish_l';
  for I := 0 to Spec.School - 1 do
  begin
    Fx := Spec.Cx + Rnd(-190, 130) * ADir * Spread - 61;
    Fy := Spec.Cy + Rnd(-80, 80) * Spread - 23;
    Po := FInner.AddPoster(Img);
    Po.Pos(Fx, Fy);
    Po.SetColor(Tint);
    Keep(FAnimator.LoopV(Po, fTranslation, V(Fx, Fy), V(Rnd(5, 12), Rnd(4, 9)), Rnd(1.6, 3.2), Rnd(0, 6.28)));
  end;
end;

{ Bursts of exhaled bubbles rising from the diver's regulator }
procedure TCreature.AddExhale(const Spec: TSpec; ADir: Integer; Tint: Cardinal);
var
  I: Integer;
  Ex, X0, Sz, Ey: Single;
  B: TNode;
  A: TAnim;
  P1: TVec2;
begin
  Ex := Spec.Exhale.X;
  Ey := Spec.Exhale.Y;
  if ADir = -1 then Ex := 2 * Spec.Cx - Ex;
  for I := 0 to 4 do
  begin
    B := FInner.AddPoster('bubble');
    Sz := Rnd(14, 26);
    B.Scale(Sz / 64, Sz / 64);
    B.SetColor(Tint);
    B.Opacity := 0;
    A := FAnimator.New(4.5, True);
    A.Delay := I * 0.18;
    X0 := Ex + Rnd(-6, 6);
    P1 := V(X0 + Rnd(-20, 20), Ey - 220);
    A.KeysV(B, fTranslation, [0, 0.6, 1], [V(X0, Ey), P1, P1]);
    A.KeysF(B, fOpacity, [0, 0.04, 0.5, 0.6, 1], [0, 0.9, 0.4, 0, 0]);
    A.Start;
    Keep(A);
  end;
end;

{ Swim across the screen and then report done }
procedure TCreature.StartCross(const Spec: TSpec; S: Single; ADir: Integer; Persp, SpeedK: Single);
const
  N = 24;
var
  HalfExt, LeftX, RightX, Sx, Ex, Y0, Y1, Dist, Speed, Bob, Waves, Ph, W, T, Slope, Ang: Single;
  Keys, Rots: array [0 .. N] of Single;
  Pts: array [0 .. N] of TVec2;
  I: Integer;
  A: TAnim;
begin
  HalfExt := MaxF(Spec.MaxX - Spec.Cx, Spec.Cx - Spec.MinX) * S;
  LeftX := -Cfg.Amp - 40 - Spec.Cx - HalfExt;
  RightX := Cfg.WorldW + Cfg.Amp + 40 - Spec.Cx + HalfExt;
  if ADir = 1 then
  begin
    Sx := LeftX;
    Ex := RightX;
  end
  else
  begin
    Sx := RightX;
    Ex := LeftX;
  end;
  if Cfg.Initial then
  begin
    Sx := Rnd(100, Cfg.WorldW - 220) - Spec.Cx;
    if Cfg.Fixed then Sx := Cfg.Sx0 - Spec.Cx;
  end;

  Y0 := Cfg.Y - Spec.Cy;
  Y1 := Y0 + Rnd(-90, 90);
  if Cfg.Fixed then Y1 := Y0 + Cfg.Dy;
  if Spec.Flat then Y1 := Y0;
  Dist := Abs(Ex - Sx);
  if Dist < 1 then Dist := 1;
  Speed := Spec.Speed * Persp * SpeedK;
  Bob := Spec.Bob * Persp;
  Waves := Dist / Rnd(600, 1000);
  if Cfg.Fixed then Waves := Dist / Cfg.Wave;
  Ph := Rnd(0, 6.28);
  if Cfg.Fixed then Ph := Cfg.Ph;
  W := Waves * TwoPi;

  for I := 0 to N do
  begin
    T := I / N;
    Keys[I] := T;
    Pts[I] := V(Sx + (Ex - Sx) * T, Y0 + (Y1 - Y0) * T + Bob * Sin(T * W + Ph));
    // nose up or down along the path
    Slope := ((Y1 - Y0) + Bob * W * Cos(T * W + Ph)) / Dist;
    Ang := EnsureRange(ArcTan(-Slope) * ADir, -0.25, 0.25);
    Rots[I] := Ang;
  end;
  Root.Pos(Pts[0].X, Pts[0].Y);
  Root.Rot := Rots[0];

  A := FAnimator.New(Dist / Speed);
  A.Delay := Cfg.Delay;
  A.KeysV(Root, fTranslation, Keys, Pts);
  A.KeysF(Root, fRotation, Keys, Rots);
  Watch(A);
end;

{ Drift upward (jellyfish) }
procedure TCreature.StartRise(const Spec: TSpec; S, Persp, SpeedK: Single);
var
  X0, Sy, Ey, Drift, Ph, T: Single;
  Keys: array [0 .. 16] of Single;
  Pts: array [0 .. 16] of TVec2;
  I: Integer;
  A: TAnim;
begin
  X0 := Cfg.X - Spec.Cx;
  Sy := 1180;
  if Cfg.Initial then Sy := Rnd(150, 900);
  Ey := -400 - Spec.Cy * S;
  Drift := Rnd(-160, 160);
  Ph := Rnd(0, 6.28);
  for I := 0 to 16 do
  begin
    T := I / 16;
    Keys[I] := T;
    Pts[I] := V(X0 + Drift * T + 30 * Persp * Sin(T * 9 + Ph), Sy + (Ey - Sy) * T);
  end;
  Root.Pos(Pts[0].X, Pts[0].Y);
  A := FAnimator.New((Sy - Ey) / (Spec.Speed * Persp * SpeedK));
  A.Delay := Cfg.Delay;
  A.KeysV(Root, fTranslation, Keys, Pts);
  Watch(A);
end;

{ Patrol back and forth around a home point forever, turning at each end (clownfish at the anemone) }
procedure TCreature.StartHover(const Spec: TSpec; SY, S: Single);
var
  Hx, Hy, R: Single;
  PA, PB: TVec2;
  A: TAnim;
  Side: string;
  Tail: TNode;
begin
  Hx := Cfg.Home.X - Spec.Cx;
  Hy := Cfg.Home.Y - Spec.Cy;
  R := Cfg.Range;
  PA := V(Hx - R, Hy + Rnd(-25, 25));
  PB := V(Hx + R, Hy + Rnd(-25, 25));
  A := FAnimator.New(Rnd(13, 18), True);
  if Cfg.Period <> 0 then A.Duration := Cfg.Period * Rnd(0.9, 1.1);
  A.KeysV(Root, fTranslation, [0, 0.12, 0.24, 0.36, 0.46, 0.5, 0.62, 0.74, 0.86, 0.96, 1],
    [PA, V(Hx - R * 0.5, PA.Y - 22), V(Hx, Hy - 34), V(Hx + R * 0.5, PB.Y - 18), PB, V(PB.X + 6, PB.Y + 4),
    V(Hx + R * 0.5, PB.Y + 16), V(Hx, Hy + 20), V(Hx - R * 0.5, PA.Y + 14), PA, PA]);
  // turning: squeeze to a sliver, swap facing, expand again
  A.KeysV(Root, fScale, [0, 0.45, 0.475, 0.5, 0.95, 0.975, 1],
    [V(S, SY), V(S, SY), V(S * 0.08, SY), V(S, SY), V(S, SY), V(S * 0.08, SY), V(S, SY)]);
  A.KeysF(FParts['gR'], fOpacity, [0, 0.474, 0.476, 0.974, 0.976, 1], [1, 1, 0, 0, 1, 1]);
  A.KeysF(FParts['gL'], fOpacity, [0, 0.474, 0.476, 0.974, 0.976, 1], [0, 0, 1, 1, 0, 0]);
  // the tail folds in toward the body through each turn; at full width it would stick out past the
  // squeezed body as a separate sliver and look detached for a moment
  for Side in TArray<string>.Create('R', 'L') do
    if FParts.TryGetValue(Side + 'tail', Tail) then
      A.KeysV(Tail, fScale, [0, 0.43, 0.475, 0.51, 0.93, 0.975, 1],
        [V(1, 1), V(1, 1), V(0.15, 0.7), V(1, 1), V(1, 1), V(0.15, 0.7), V(1, 1)]);
  Root.Pos(PA.X, PA.Y);
  A.Start;
  Keep(A);
end;

{ Stay at a home spot, gently bobbing and swaying (seahorses) }
procedure TCreature.StartBob(const Spec: TSpec);
var
  Home: TVec2;
  R, Per, Ph, T, Ang: Single;
  Keys: array [0 .. 32] of Single;
  Pts: array [0 .. 32] of TVec2;
  I: Integer;
  A: TAnim;
begin
  Home := V(Cfg.Home.X - Spec.Cx, Cfg.Home.Y - Spec.Cy);
  Root.Pos(Home.X, Home.Y);
  if Cfg.HasRange then
  begin
    // drift slowly around home in a lazy figure-eight, always facing the same way
    R := Cfg.Range;
    Per := 30;
    if Cfg.Period <> 0 then Per := Cfg.Period * Rnd(0.9, 1.1);
    Ph := Rnd(0, 6.28);
    for I := 0 to 32 do
    begin
      T := I / 32;
      Ang := T * TwoPi;
      Keys[I] := T;
      Pts[I] := V(Home.X + R * Sin(Ang + Ph), Home.Y + R * 0.45 * Sin(2 * Ang + Ph) + 10 * Sin(5 * Ang));
    end;
    A := FAnimator.New(Per, True);
    A.KeysV(Root, fTranslation, Keys, Pts);
    Root.Pos(Pts[0].X, Pts[0].Y);
    A.Start;
    Keep(A);
  end
  else
    Keep(FAnimator.LoopV(Root, fTranslation, Home, V(Rnd(4, 9), Rnd(10, 18)), Rnd(5, 8), Rnd(0, 6.28)));
  Keep(FAnimator.LoopF(Root, fRotation, 0, Rnd(0.04, 0.08), Rnd(6, 9), Rnd(0, 6.28)));
end;

{ Sneak up to a baited hook, hesitate, dart in to grab the bait (at 68% of the time) and race away }
procedure TCreature.StartSteal(const Spec: TSpec; S: Single; ADir: Integer);
var
  HalfExt, Hx, Hy, LeftX, RightX, Sx, Ex, W: Single;
  A: TAnim;
begin
  HalfExt := MaxF(Spec.MaxX - Spec.Cx, Spec.Cx - Spec.MinX) * S;
  Hx := Cfg.HookX - Spec.Cx - ADir * (Spec.MaxX - 12 - Spec.Cx) * S;
  Hy := Cfg.HookY - Spec.Cy;
  LeftX := -Cfg.Amp - 40 - Spec.Cx - HalfExt;
  RightX := Cfg.WorldW + Cfg.Amp + 40 - Spec.Cx + HalfExt;
  if ADir = 1 then
  begin
    Sx := LeftX;
    Ex := RightX;
  end
  else
  begin
    Sx := RightX;
    Ex := LeftX;
  end;
  W := Hx - ADir * 150;
  Root.Pos(Sx, Hy + 70);
  A := FAnimator.New(Cfg.Duration);
  A.Delay := Cfg.Delay;
  A.KeysV(Root, fTranslation, [0, 0.45, 0.5, 0.55, 0.6, 0.64, 0.68, 1],
    [V(Sx, Hy + 70), V(W, Hy + 12), V(W - ADir * 30, Hy + 16), V(W + ADir * 20, Hy + 6), V(W - ADir * 15, Hy + 10),
    V(W, Hy + 8), V(Hx, Hy), V(Ex, Hy - 90)]);
  Watch(A);
end;

{ Dart away from a shark: a burst of speed that eases off, veering up or down, out of the screen }
procedure TCreature.StartFlee(const Spec: TSpec; S, Sy: Single; ADir: Integer; Persp, SpeedK: Single);
var
  HalfExt, X0, Y0, Ex, Dy, Lo, Hi, Yc, Dist, Duration, T, U, W, K: Single;
  Keys, Rots: array [0 .. 16] of Single;
  Pts: array [0 .. 16] of TVec2;
  I, Sgn: Integer;
  A: TAnim;
begin
  HalfExt := MaxF(Spec.MaxX - Spec.Cx, Spec.Cx - Spec.MinX) * S;
  X0 := Cfg.StartPos.X - Spec.Cx;
  Y0 := Cfg.StartPos.Y - Spec.Cy;
  if ADir = 1 then
    Ex := Cfg.WorldW + Cfg.Amp + 40 - Spec.Cx + HalfExt
  else
    Ex := -Cfg.Amp - 40 - Spec.Cx - HalfExt;
  Dy := Cfg.FleeY * Rnd(150, 260) * Persp;
  // stay in this layer's own swimming band: below it the reef and sand of the nearer layers are drawn
  // in front, and a fish diving there vanishes behind them. With no room on the chosen side, go the other way.
  Lo := MaxF(70, Cfg.YMin);
  Hi := Cfg.YMax;
  if Hi <= Lo then Hi := 900;
  Yc := Cfg.StartPos.Y;
  if (Dy > 0) and (Hi - Yc < 60) then Dy := -Dy;
  if (Dy < 0) and (Yc - Lo < 60) then Dy := -Dy;
  if Yc + Dy > Hi then Dy := Hi - Yc;
  if Yc + Dy < Lo then Dy := Lo - Yc;
  Dist := Abs(Ex - X0);
  if Dist < 50 then Dist := 50;
  // average speed 1.9x normal; with the ease-out the first moment is nearly 4x
  Duration := Dist / (Spec.Speed * Persp * SpeedK * 1.9);
  Sgn := Sign(Dy);
  for I := 0 to 16 do
  begin
    T := I / 16;
    Keys[I] := T;
    U := 1 - (1 - T) * (1 - T);
    W := 1 - Power(1 - T, 6);
    Pts[I] := V(X0 + (Ex - X0) * U, Y0 + Dy * W);
    Rots[I] := Sgn * ADir * 0.38 * Power(1 - T, 3);
  end;
  Root.Pos(Pts[0].X, Pts[0].Y);
  Root.Rot := Rots[0];
  A := FAnimator.New(Duration);
  A.KeysV(Root, fTranslation, Keys, Pts);
  A.KeysF(Root, fRotation, Keys, Rots);
  if Cfg.Turned then
  begin
    // a quick turn: squeezed to a sliver, then full width facing the other way
    K := Min(0.2 / Duration, 0.3);
    A.KeysV(Root, fScale, [0, K, 1], [V(S * 0.1, S * Sy), V(S, S * Sy), V(S, S * Sy)]);
    Root.Scale(S * 0.1, S * Sy);
  end;
  Watch(A);
end;

{ A pufferfish puffs up where it is. Its inflating frames (the same drawing from fish to spiky ball, already
  there but invisible) fade in one over the other, each a little rounder, so it swells smoothly; then it drifts
  slowly up and away on a gentle current, wobbling. Nothing is rebuilt, so nothing blinks. }
procedure TCreature.PuffUp(const Spec: TSpec);
const
  T0 = 0.12;   // seconds for frame 0 to take over
  Dt = 0.34;   // seconds per following frame
var
  S, Persp, X0, Y0, Ey, Drift, Ph, Dist, Duration, U, W, Gx, Gy, K, TA, TB, Te: Single;
  Keys: array [0 .. 32] of Single;
  Pts: array [0 .. 32] of TVec2;
  I, N: Integer;
  A: TAnim;
  Id: string;
  Part: TNode;
begin
  FAnimator.Kill(FSwim);
  FAnims.Remove(FSwim);
  FSwim := nil;
  Fleeable := False;
  Cfg.Mode := mPuff;
  S := Root.Sx;
  Persp := 0.22 + 0.78 * Cfg.Depth;
  X0 := Root.Tx;
  Y0 := Root.Ty;
  Ey := -130 * S - Spec.Cy - 40;
  // a current carries it sideways across the screen (toward the side with more room) as it rises
  Drift := Rnd(160, 340);
  if X0 + Spec.Cx > Cfg.WorldW / 2 then Drift := -Drift;
  Ph := Rnd(0, 6.28);
  Dist := Y0 - Ey;
  if Dist < 100 then Dist := 100;
  Duration := Sqrt(Dist * Dist + Drift * Drift) / (9 + 12 * Persp);
  for I := 0 to 32 do
  begin
    U := I / 32;
    Keys[I] := U;
    // a slow start while it swells, then a steady rise
    W := U * U * (3 - 2 * U) * 0.35 + U * 0.65;
    // the current comes in gusts: the sideways drift surges and eases, and the rise dips now and then
    Gx := Drift * (W + 0.09 * (Sin(U * 13 + Ph) - Sin(Ph)));
    Gy := 18 * Persp * (Sin(U * 11 + Ph * 1.7) - Sin(Ph * 1.7)) * (1 - U * 0.5);
    Pts[I] := V(X0 + Gx, Y0 + (Ey - Y0) * W + Gy);
  end;
  A := FAnimator.New(Duration);
  A.KeysV(Root, fTranslation, Keys, Pts);
  K := 1 / Duration;   // one second, as a fraction of the whole animation
  A.KeysF(Root, fRotation, [0, K, 1], [Root.Rot, 0, 0]);
  // frame 0 looks just like the swimming fish: it takes over at once, then each next frame fades in on top
  N := Spec.Puff;
  for I := 0 to N - 1 do
  begin
    Part := FParts['f' + I.ToString];
    if I = 0 then
      A.KeysF(Part, fOpacity, [0, T0 * K, 1], [0, 1, 1])
    else
    begin
      TA := T0 + (I - 1) * Dt;
      TB := T0 + I * Dt;
      A.KeysF(Part, fOpacity, [0, TA * K, TB * K, 1], [0, 0, 1, 1]);
    end;
  end;
  // the separate swimming parts go once frame 0 covers them
  for Id in TArray<string>.Create('tail', 'body', 'pec') do
    A.KeysF(FParts[Id], fOpacity, [0, T0 * K, (T0 + 0.05) * K, 1], [1, 1, 0, 0]);
  // a little overshoot as it reaches full size
  Te := T0 + (N - 1) * Dt;
  A.KeysV(Root, fScale, [0, (Te - 0.3) * K, Te * K, (Te + 0.35) * K, 1],
    [V(S, S), V(S, S), V(S * 1.07, S * 1.07), V(S, S), V(S, S)]);
  Keep(FAnimator.LoopF(FInner, fRotation, 0, 0.17, 6.5, 0));
  Watch(A);
end;

end.
