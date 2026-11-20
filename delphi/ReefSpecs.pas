unit ReefSpecs;

{ Creature definitions (the same numbers as components/Specs.brs in the Roku version).
  All artwork faces right; parts are listed back to front.
    X, Y, W  = part position and image width inside the creature (W is used to mirror it)
    Px, Py   = pivot (joint) for rotation / scale animation
    Anim     = paRot (swing rotation by Amp) or paScale (pulse scale by Samp)
    Po       = phase offset for that part's motion (radians); Op = fixed opacity
    Prey     = darts away from sharks
    Flat     = keeps a level path (crawlers); Hop = little bounce period; NoFlip = never mirrored
    Season   = part only drawn in that season ("xmas"); Night = only when spawned in the dark;
    Sym      = same image facing either way; Light = no depth tint
    Puff     = puffs up instead of fleeing (the number of inflating frames, parts f0..)
    Cx, Cy   = creature centre; MinX / MaxX = horizontal extent (for off-screen maths)
    Scale    = size at depth 1 (closest); Speed = pixels per second at depth 1; Bob = vertical wave }

interface

uses
  System.SysUtils, System.Generics.Collections, ReefEngine;

type
  TPartAnim = (paNone, paRot, paScale);

  TPart = record
    Id, Uri, Season: string;
    W, H, X, Y, Px, Py, Amp, Period, Po, Sph, Rot, Op, Dark: Single;
    Samp: TVec2;
    HasPivot, HasSamp, Night, Sym, Light: Boolean;
    Anim: TPartAnim;
    function Pivot(APx, APy: Single): TPart;
    function Swing(AAmp, APeriod: Single; APo: Single = 0): TPart;
    function Stretch(ASx, ASy, ASph: Single): TPart;
    function Pulse(ASx, ASy, APeriod: Single; APo: Single = 0): TPart;
    function Tall(AH: Single): TPart;
    function Turned(ARot: Single): TPart;
    function Faded(AOp: Single): TPart;
    function Darker(ADark: Single): TPart;
    function Lit: TPart;
  end;

  TSpec = record
    Prey, Flat, NoFlip, HasExhale: Boolean;
    Puff, School: Integer;
    Cx, Cy, MinX, MaxX, Scale, Speed, Bob, Sy: Single;
    Sway, SwayPeriod, Flap, Hop, Crawl: Single;   // 0 = none
    Exhale: TVec2;
    Parts: TArray<TPart>;
  end;

  TSpecs = TDictionary<string, TSpec>;

function BuildSpecs: TSpecs;

implementation

function P(const Id, Uri: string; W, X, Y: Single): TPart;
begin
  Result := Default(TPart);
  Result.Id := Id;
  Result.Uri := Uri;
  Result.W := W;
  Result.X := X;
  Result.Y := Y;
  Result.Op := 1;
  Result.Dark := 1;
end;

function TPart.Pivot(APx, APy: Single): TPart;
begin
  Result := Self;
  Result.HasPivot := True;
  Result.Px := APx;
  Result.Py := APy;
end;

function TPart.Swing(AAmp, APeriod, APo: Single): TPart;
begin
  Result := Self;
  Result.Anim := paRot;
  Result.Amp := AAmp;
  Result.Period := APeriod;
  Result.Po := APo;
end;

function TPart.Stretch(ASx, ASy, ASph: Single): TPart;
begin
  Result := Self;
  Result.HasSamp := True;
  Result.Samp := V(ASx, ASy);
  Result.Sph := ASph;
end;

function TPart.Pulse(ASx, ASy, APeriod, APo: Single): TPart;
begin
  Result := Self;
  Result.Anim := paScale;
  Result.HasSamp := True;
  Result.Samp := V(ASx, ASy);
  Result.Period := APeriod;
  Result.Po := APo;
end;

function TPart.Tall(AH: Single): TPart;
begin
  Result := Self;
  Result.H := AH;
end;

function TPart.Turned(ARot: Single): TPart;
begin
  Result := Self;
  Result.Rot := ARot;
end;

function TPart.Faded(AOp: Single): TPart;
begin
  Result := Self;
  Result.Op := AOp;
end;

function TPart.Darker(ADark: Single): TPart;
begin
  Result := Self;
  Result.Dark := ADark;
end;

function TPart.Lit: TPart;
begin
  Result := Self;
  Result.Light := True;
end;

function S(Cx, Cy, MinX, MaxX, Scale, Speed, Bob: Single; const Parts: array of TPart): TSpec;
var
  I: Integer;
begin
  Result := Default(TSpec);
  Result.Cx := Cx;
  Result.Cy := Cy;
  Result.MinX := MinX;
  Result.MaxX := MaxX;
  Result.Scale := Scale;
  Result.Speed := Speed;
  Result.Bob := Bob;
  Result.Sy := 1;
  SetLength(Result.Parts, Length(Parts));
  for I := 0 to High(Parts) do Result.Parts[I] := Parts[I];
end;

function BuildSpecs: TSpecs;
var
  Sp: TSpec;
  Pt: TPart;
  I: Integer;
  Arms: TArray<TPart>;
begin
  Result := TSpecs.Create;

  Result.Add('clown', S(117, 72, -48, 235, 0.85, 100, 30, [
    P('tail', 'clown_tail', 72, -48, 24).Pivot(70, 50).Swing(0.3, 0.45),
    P('body', 'clown_body', 235, 0, 0),
    P('pec', 'clown_pec', 32, 126, 74).Pivot(26, 11).Swing(0.3, 0.4, 1.0).Stretch(-0.3, 0, 1.57)]));

  Sp := S(130, 90, -46, 262, 0.85, 120, 35, [
    P('tail', 'tang_tail', 82, -46, 34).Pivot(80, 56).Swing(0.25, 0.5),
    P('body', 'tang_body', 262, 0, 0),
    P('pec', 'tang_pec', 40, 158, 96).Pivot(34, 4).Swing(0.3, 0.5, 1.0).Stretch(-0.3, 0, 1.57)]);
  Sp.Prey := True;
  Result.Add('tang', Sp);

  Sp := S(110, 100, -36, 222, 0.8, 105, 30, [
    P('tail', 'ytang_tail', 72, -36, 45).Pivot(70, 55).Swing(0.25, 0.5),
    P('body', 'ytang_body', 222, 0, 0),
    P('pec', 'ytang_pec', 34, 142, 102).Pivot(28, 3).Swing(0.3, 0.5, 1.0).Stretch(-0.3, 0, 1.57)]);
  Sp.Prey := True;
  Result.Add('ytang', Sp);

  Sp := S(125, 105, -34, 250, 0.8, 90, 30, [
    P('tail', 'angel_tail', 72, -34, 55).Pivot(70, 50).Swing(0.22, 0.6),
    P('body', 'angel_body', 250, 0, 0),
    P('pec', 'angel_pec', 38, 146, 110).Pivot(32, 4).Swing(0.28, 0.6, 1.0).Stretch(-0.3, 0, 1.57)]);
  Sp.Prey := True;
  Result.Add('angel', Sp);

  Sp := S(400, 165, -220, 850, 0.75, 150, 40, [
    P('tail', 'shark_tail', 272, -220, 4).Pivot(270, 162).Swing(0.16, 1.5),
    P('dorsal', 'shark_dorsal', 136, 444, 2).Pivot(70, 104).Swing(0.06, 1.5, 0.6),
    P('pecf', 'shark_pecf', 78, 566, 201).Pivot(50, 7).Swing(0.16, 2.4, 1.2),
    P('body', 'shark_body', 850, 0, 0),
    P('pec', 'shark_pec', 134, 486, 196).Pivot(95, 10).Swing(0.16, 2.4, 1.0)]);
  Sp.Sway := 0.015;
  Sp.SwayPeriod := 1.5;
  Result.Add('shark', Sp);

  Result.Add('turtle', S(300, 160, -22, 590, 0.7, 65, 35, [
    P('ffar', 'turtle_flipper', 290, 153, 134).Pivot(275, 30).Swing(0.38, 3.4, 0.4).Darker(0.6),
    P('rear', 'turtle_rear', 132, -22, 158).Pivot(122, 14).Swing(0.15, 3.4, 1.5),
    P('body', 'turtle_body', 590, 0, 0),
    P('fnear', 'turtle_flipper', 290, 128, 146).Pivot(275, 30).Swing(0.38, 3.4)]));

  Sp := S(265, 210, 0, 530, 0.75, 85, 50, [P('body', 'manta', 530, 0, 0)]);
  Sp.Sy := 0.62;
  Sp.Flap := 4.0;
  Result.Add('manta', Sp);

  Sp := S(100, 150, 0, 200, 0.7, 22, 0, [
    P('glow', 'jelly_glow', 260, -30, -40).Faded(0.45),
    P('tent', 'jelly_tentacles', 200, 0, 98).Pivot(100, 0).Pulse(-0.05, 0.06, 2.6),
    P('bell', 'jelly_bell', 200, 0, 0).Pivot(100, 110).Pulse(0.1, -0.13, 2.6)]);
  Sp.NoFlip := True;
  Result.Add('jelly', Sp);

  Sp := S(650, 220, 0, 1300, 1.7, 55, 25, [
    P('body', 'whale', 1300, 0, 0).Tall(430),
    P('fin', 'whale_fin', 328, 606, 282).Tall(148).Pivot(280, 6).Swing(0.07, 6.0)]);
  Sp.Sway := 0.015;
  Sp.SwayPeriod := 9;
  Result.Add('whale', Sp);

  Result.Add('lionfish', S(140, 110, -34, 280, 0.8, 45, 20, [
    P('tail', 'lion_tail', 80, -34, 75).Pivot(78, 45).Swing(0.18, 0.9),
    P('body', 'lion_body', 280, 0, 0),
    P('fin', 'lion_fin', 200, -20, 110).Pivot(190, 20).Swing(0.12, 2.6)]));

  Result.Add('octopus', S(-30, 90, -244, 170, 0.75, 55, 30, [
    P('arms', 'octo_arms', 300, -244, 20).Pivot(296, 80).Pulse(-0.2, 0.1, 1.8),
    P('body', 'octo_body', 170, 0, 0).Pivot(110, 70).Pulse(0.06, -0.05, 1.8, 0.6)]));

  Sp := S(230, 110, -88, 540, 0.8, 260, 70, [
    P('tail', 'dolphin_tail', 140, -88, 59).Pivot(136, 62).Swing(0.3, 0.8),
    P('dorsal', 'dolphin_dorsal', 70, 264, 2).Pivot(36, 66).Swing(0.08, 0.8, 0.6),
    P('body', 'dolphin_body', 540, 0, 0),
    P('pec', 'dolphin_pec', 68, 336, 138).Pivot(45, 3).Swing(0.3, 1.2, 1.0)]);
  Sp.Sway := 0.02;
  Sp.SwayPeriod := 0.8;
  Result.Add('dolphin', Sp);

  Result.Add('seahorse', S(65, 115, -10, 130, 0.85, 0, 0, [
    P('fin', 'seahorse_fin', 44, -10, 78).Pivot(42, 22).Pulse(-0.4, 0, 0.25),
    P('body', 'seahorse', 130, 0, 0)]));

  Sp := S(110, 90, -41, 261, 0.5, 40, 0, [
    P('legsL', 'crab_legs', 100, -41, 72).Pivot(96, 20).Swing(0.22, 0.35),
    P('legsR', 'crab_legs_l', 100, 161, 72).Pivot(4, 20).Swing(0.22, 0.35, 3.14),
    P('body', 'crab_body', 220, 0, 0)]);
  Sp.Flat := True;
  Sp.NoFlip := True;
  Sp.Hop := 0.35;
  Result.Add('crab', Sp);

  // sea star: five arms round a disc, each reaching and pulling in turn
  SetLength(Arms, 6);
  for I := 0 to 4 do
    Arms[I] := P('a' + I.ToString, 'seastar_arm', 50, 40, 3).Pivot(25, 62).Turned(I * 1.2566)
      .Swing(0.17, 3.2, I * 1.2566).Stretch(0, -0.16, 1.57);
  Arms[5] := P('disc', 'seastar_disc', 60, 35, 35);
  Sp := S(65, 65, 0, 130, 0.55, 9, 0, Arms);
  Sp.Flat := True;
  Sp.NoFlip := True;
  Sp.Sway := 0.05;
  Sp.SwayPeriod := 16;
  Sp.Crawl := 3.2;
  Result.Add('star', Sp);

  // Scuba Steve
  Pt := P('torch', 'diver_torch', 80, 220, 52);
  Pt.Night := True;
  Sp := S(100, 66, -104, 300, 1.3, 45, 15, [
    P('legF', 'diver_leg', 200, -104, 42).Pivot(196, 30).Swing(0.18, 1.6, 3.14).Darker(0.7),
    P('legN', 'diver_leg', 200, -96, 46).Pivot(196, 30).Swing(0.18, 1.6),
    P('body', 'diver_body', 300, 0, 0),
    Pt,
    P('hat', 'diver_hat', 90, 222, -8).Lit]);
  Sp.Parts[4].Season := 'xmas';
  Sp.HasExhale := True;
  Sp.Exhale := V(292, 70);
  Result.Add('diver', Sp);

  // the diver's torch beam: a twin that swims the diver's exact path in a layer above the night shade
  // (same centre, extent, scale, speed and bob as the diver, so the two stay together)
  Result.Add('diverlight', S(100, 66, -104, 300, 1.3, 45, 15, [
    P('beam', 'diver_beam', 640, 286, 23).Tall(300).Pivot(6, 90).Lit.Swing(0.09, 7.0)]));

  // pufferfish (rare): crosses like any fish; only a shark heading its way makes it puff up and float away
  Sp := S(120, 120, 0, 240, 1.0, 55, 18, [
    P('tail', 'puffer_tail', 50, 0, 85).Pivot(48, 35).Swing(0.3, 0.5),
    P('body', 'puffer_body', 240, 0, 0).Tall(240),
    P('pec', 'puffer_pec', 30, 109, 121).Pivot(25, 4).Swing(0.35, 0.35, 1.0),
    // the inflating frames (fish .. spiky ball), invisible until a shark comes
    P('f0', 'puffer_f0', 240, 0, 0).Tall(240).Faded(0),
    P('f1', 'puffer_f1', 240, 0, 0).Tall(240).Faded(0),
    P('f2', 'puffer_f2', 240, 0, 0).Tall(240).Faded(0),
    P('f3', 'puffer_f3', 240, 0, 0).Tall(240).Faded(0),
    P('f4', 'puffer_f4', 240, 0, 0).Tall(240).Faded(0),
    P('f5', 'puffer_f5', 240, 0, 0).Tall(240).Faded(0)]);
  Sp.Prey := True;
  Sp.Puff := 6;
  Result.Add('puffer', Sp);

  // Captain Greg's research submarine, far away; its headlight is the twin "sublight"
  Result.Add('sub', S(330, 150, -6, 660, 0.6, 90, 8, [
    P('prop', 'sub_prop', 30, -6, 90).Pivot(15, 60).Pulse(0, -0.5, 0.3),
    P('body', 'sub_body', 660, 0, 0)]));
  Result.Add('sublight', S(330, 150, -6, 660, 0.6, 90, 8, [
    P('beam', 'diver_beam', 960, 643, 15).Tall(450).Pivot(9, 135).Lit]));

  // anglerfish (night only): a dark body under the night shade; the glowing lure is the twin "anglerlight"
  Result.Add('angler', S(135, 115, -26, 270, 0.8, 30, 14, [
    P('tail', 'angler_tail', 60, -26, 75).Pivot(58, 45).Swing(0.2, 1.1),
    P('body', 'angler_body', 270, 0, 0),
    P('pec', 'angler_pec', 40, 118, 130).Pivot(34, 4).Swing(0.25, 1.3, 1.0)]));
  Pt := P('lure', 'glow_dot', 110, 187, -31).Tall(110).Pivot(55, 55).Lit.Pulse(0.3, 0.3, 2.2);
  Pt.Sym := True;
  Result.Add('anglerlight', S(135, 115, -26, 270, 0.8, 30, 14, [Pt]));

  Sp := S(240, 100, 0, 480, 0.6, 150, 40, []);
  Sp.Prey := True;
  Sp.School := 14;
  Result.Add('school', Sp);
end;

end.
