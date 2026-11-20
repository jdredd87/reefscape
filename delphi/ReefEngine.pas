unit ReefEngine;

{ A small scene graph and animation engine, drawn with OpenGL.

  It follows the model the Roku version is built on, so the reef code ports over almost line for line:
  - TNode    = a Group, Poster (image) or Rectangle with translation, rotation, scale (about a pivot),
               opacity, tint and an optional clipping rectangle. Children are drawn in order, back to front.
  - TAnim    = an animation with one or more tracks; each track moves one field of one node through
               key frames (or along a sine wave), optionally looping.
  All coordinates are in the 1920 x 1080 design space; the view matrix scales that to the window. }

interface

uses
  Winapi.Windows, Winapi.OpenGL, System.SysUtils, System.Classes, System.Math,
  System.Generics.Collections;

type
  TVec2 = record
    X, Y: Single;
  end;

  { 2 x 3 affine matrix:  x' = A*x + C*y + E,  y' = B*x + D*y + F }
  TMat = record
    A, B, C, D, E, F: Single;
  end;

  TTexture = class
  public
    Id: GLuint;
    W, H: Integer;      // image size in pixels
    U, V: Single;       // texture coordinates of the image's right / bottom edge
    destructor Destroy; override;
  end;

  TNodeKind = (nkGroup, nkPoster, nkRect);
  TField = (fTranslation, fRotation, fScale, fOpacity);

  TNode = class
  private
    FChildren: TObjectList<TNode>;
    function GetChild(Index: Integer): TNode;
  public
    Parent: TNode;
    Kind: TNodeKind;
    Name: string;
    Tx, Ty: Single;           // translation
    Rot: Single;              // radians, positive = counter-clockwise (as on Roku)
    Sx, Sy: Single;           // scale
    Px, Py: Single;           // pivot for rotation and scale
    Opacity: Single;
    Visible: Boolean;
    Tex: TTexture;            // posters
    W, H: Single;             // 0 = the image's own size
    R, G, B: Single;          // tint (posters) or colour (rectangles)
    HasClip: Boolean;
    ClipX, ClipY, ClipW, ClipH: Single;
    constructor Create(AKind: TNodeKind);
    destructor Destroy; override;
    function AddGroup(const AName: string = ''): TNode;
    function InsertGroup(Index: Integer): TNode;
    function AddPoster(const Img: string): TNode;
    function AddRect(AW, AH: Single; Color: Cardinal): TNode;
    procedure Clear;
    function Count: Integer;
    property Children[Index: Integer]: TNode read GetChild; default;
    procedure SetImage(const Img: string);
    function Pos(X, Y: Single): TNode;
    function Pivot(X, Y: Single): TNode;
    function Scale(X, Y: Single): TNode;
    function Size(AW, AH: Single): TNode;
    procedure SetColor(Color: Cardinal);
    procedure SetClip(X, Y, AW, AH: Single);
    function LocalMatrix: TMat;
    function Find(const AName: string): TNode;
  end;

  TEase = (eLinear, eOutQuad, eInQuad);
  TTrackKind = (tkKeys, tkSine);

  TTrack = record
    Node: TNode;
    Field: TField;
    Kind: TTrackKind;
    Keys: TArray<Single>;
    Vals: TArray<TVec2>;      // float fields use X only
    Base, Amp: TVec2;         // sine tracks: Base + Amp * sin(2*pi*t + Phase)
    Phase: Single;
  end;

  TAnim = class
  private
    FTracks: TArray<TTrack>;
    procedure Apply(F: Single);
  public
    Duration, Delay: Single;
    Loop: Boolean;
    Ease: TEase;
    Running, Dead: Boolean;
    Time: Single;
    OnDone: TProc;
    procedure Start;
    procedure Stop;
    procedure ClearTracks;
    procedure KeysF(Node: TNode; Field: TField; const Keys, Vals: array of Single);
    procedure KeysV(Node: TNode; Field: TField; const Keys: array of Single; const Vals: array of TVec2);
    procedure SineF(Node: TNode; Field: TField; Center, Amp, Phase: Single);
    procedure SineV(Node: TNode; Field: TField; const Base, Amp: TVec2; Phase: Single);
  end;

  TAnimator = class
  private
    FList: TObjectList<TAnim>;
  public
    constructor Create;
    destructor Destroy; override;
    function New(Duration: Single; Loop: Boolean = False): TAnim;
    { started, looping: Center + Amp * sin(2*pi*t/Period + Phase) }
    function LoopF(Node: TNode; Field: TField; Center, Amp, Period, Phase: Single): TAnim;
    function LoopV(Node: TNode; Field: TField; const Base, Amp: TVec2; Period, Phase: Single): TAnim;
    procedure Kill(A: TAnim);
    procedure Update(Dt: Single);
  end;

  TTextureStore = class
  private
    FMap: TObjectDictionary<string, TTexture>;
    FReady, FNPOT: Boolean;
    FGenMipmap: procedure(Target: GLenum); stdcall;
    procedure Init;
    function Upload(W, H: Integer; Pixels: Pointer; Mipmaps: Boolean): TTexture;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const Name: string): TTexture;
    { white text as a texture (premultiplied alpha); the caller owns it }
    function MakeText(const Text, FontName: string; PixelHeight: Integer; Bold: Boolean): TTexture;
  end;

function V(X, Y: Single): TVec2; inline;
function Rnd(A, B: Single): Single;
function MaxF(A, B: Single): Single; inline;
function TintFor(Depth: Single; Dark: Single = 1.0): Cardinal;
{ draws into the viewport whose bottom-left corner is at (OriginX, OriginY) in the window and that is ViewH high }
procedure DrawTree(Root: TNode; const View: TMat; ViewH, OriginX, OriginY: Integer);

var
  Textures: TTextureStore;

implementation

uses
  Winapi.ActiveX, Winapi.Wincodec, System.Win.ComObj, Vcl.Graphics;

const
  GL_BGRA_EXT = $80E1;
  GL_CLAMP_TO_EDGE = $812F;

function V(X, Y: Single): TVec2;
begin
  Result.X := X;
  Result.Y := Y;
end;

function Rnd(A, B: Single): Single;
begin
  Result := A + (B - A) * Random;
end;

function MaxF(A, B: Single): Single;
begin
  if A > B then Result := A else Result := B;
end;

{ Underwater colour shift: far things are bluer and darker. Depth 0 = far, 1 = near. Returns $RRGGBB }
function TintFor(Depth: Single; Dark: Single = 1.0): Cardinal;
var
  K: Single;

  function Ch(X: Single): Cardinal;
  begin
    Result := EnsureRange(Trunc(X), 0, 255);
  end;

begin
  K := 0.45 + 0.55 * Depth;
  Result := (Ch((105 + 150 * K) * Dark) shl 16) or (Ch((160 + 95 * K) * Dark) shl 8) or Ch((195 + 60 * K) * Dark);
end;

function Mul(const P, L: TMat): TMat; inline;
begin
  Result.A := P.A * L.A + P.C * L.B;
  Result.B := P.B * L.A + P.D * L.B;
  Result.C := P.A * L.C + P.C * L.D;
  Result.D := P.B * L.C + P.D * L.D;
  Result.E := P.A * L.E + P.C * L.F + P.E;
  Result.F := P.B * L.E + P.D * L.F + P.F;
end;

{ ---------- TTexture ---------- }

destructor TTexture.Destroy;
begin
  if (Id <> 0) and (wglGetCurrentContext <> 0) then glDeleteTextures(1, @Id);
  inherited;
end;

{ ---------- TNode ---------- }

constructor TNode.Create(AKind: TNodeKind);
begin
  Kind := AKind;
  Sx := 1;
  Sy := 1;
  Opacity := 1;
  Visible := True;
  R := 1;
  G := 1;
  B := 1;
end;

destructor TNode.Destroy;
begin
  FChildren.Free;
  inherited;
end;

function TNode.GetChild(Index: Integer): TNode;
begin
  Result := FChildren[Index];
end;

function TNode.Count: Integer;
begin
  if FChildren = nil then Result := 0 else Result := FChildren.Count;
end;

function TNode.InsertGroup(Index: Integer): TNode;
begin
  Result := TNode.Create(nkGroup);
  Result.Parent := Self;
  if FChildren = nil then FChildren := TObjectList<TNode>.Create(True);
  FChildren.Insert(Index, Result);
end;

function TNode.AddGroup(const AName: string): TNode;
begin
  Result := InsertGroup(Count);
  Result.Name := AName;
end;

function TNode.AddPoster(const Img: string): TNode;
begin
  Result := InsertGroup(Count);
  Result.Kind := nkPoster;
  if Img <> '' then Result.SetImage(Img);
end;

function TNode.AddRect(AW, AH: Single; Color: Cardinal): TNode;
begin
  Result := InsertGroup(Count);
  Result.Kind := nkRect;
  Result.W := AW;
  Result.H := AH;
  Result.SetColor(Color);
end;

procedure TNode.Clear;
begin
  if FChildren <> nil then FChildren.Clear;
end;

procedure TNode.SetImage(const Img: string);
begin
  Tex := Textures.Get(Img);
end;

function TNode.Pos(X, Y: Single): TNode;
begin
  Tx := X;
  Ty := Y;
  Result := Self;
end;

function TNode.Pivot(X, Y: Single): TNode;
begin
  Px := X;
  Py := Y;
  Result := Self;
end;

function TNode.Scale(X, Y: Single): TNode;
begin
  Sx := X;
  Sy := Y;
  Result := Self;
end;

function TNode.Size(AW, AH: Single): TNode;
begin
  W := AW;
  H := AH;
  Result := Self;
end;

procedure TNode.SetColor(Color: Cardinal);
begin
  R := ((Color shr 16) and $FF) / 255;
  G := ((Color shr 8) and $FF) / 255;
  B := (Color and $FF) / 255;
end;

procedure TNode.SetClip(X, Y, AW, AH: Single);
begin
  HasClip := True;
  ClipX := X;
  ClipY := Y;
  ClipW := AW;
  ClipH := AH;
end;

function TNode.LocalMatrix: TMat;
var
  S, C: Single;
begin
  if Rot = 0 then
  begin
    Result.A := Sx;
    Result.B := 0;
    Result.C := 0;
    Result.D := Sy;
  end
  else
  begin
    SinCos(Rot, S, C);
    // positive rotation is counter-clockwise on a screen whose y axis points down
    Result.A := C * Sx;
    Result.B := -S * Sx;
    Result.C := S * Sy;
    Result.D := C * Sy;
  end;
  Result.E := Tx + Px - (Result.A * Px + Result.C * Py);
  Result.F := Ty + Py - (Result.B * Px + Result.D * Py);
end;

function TNode.Find(const AName: string): TNode;
var
  I: Integer;
begin
  if Name = AName then Exit(Self);
  for I := 0 to Count - 1 do
  begin
    Result := FChildren[I].Find(AName);
    if Result <> nil then Exit;
  end;
  Result := nil;
end;

{ ---------- drawing ---------- }

type
  TClip = record
    On: Boolean;
    X0, Y0, X1, Y1: Single;   // window pixels, y down
  end;

var
  BoundTex: GLuint;
  TexOn: Boolean;
  DrawViewH, DrawOX, DrawOY: Integer;

procedure ApplyClip(const C: TClip);
var
  X, Y, W, H: Integer;
begin
  if not C.On then
  begin
    glDisable(GL_SCISSOR_TEST);
    Exit;
  end;
  X := Floor(C.X0);
  Y := Floor(C.Y0);
  W := Max(0, Ceil(C.X1) - X);
  H := Max(0, Ceil(C.Y1) - Y);
  glEnable(GL_SCISSOR_TEST);
  glScissor(DrawOX + X, DrawOY + DrawViewH - (Y + H), W, H);
end;

procedure DrawNode(N: TNode; const ParentM: TMat; Alpha: Single; const Clip: TClip);
var
  M: TMat;
  A, W, H: Single;
  I: Integer;
  C: TClip;
  X0, Y0, X1, Y1, T: Single;

  procedure Vtx(X, Y: Single);
  begin
    glVertex2f(M.A * X + M.C * Y + M.E, M.B * X + M.D * Y + M.F);
  end;

begin
  if not N.Visible then Exit;
  A := Alpha * N.Opacity;
  if A <= 0.002 then Exit;
  M := Mul(ParentM, N.LocalMatrix);
  case N.Kind of
    nkPoster:
      if N.Tex <> nil then
      begin
        W := N.W;
        if W = 0 then W := N.Tex.W;
        H := N.H;
        if H = 0 then H := N.Tex.H;
        if not TexOn then
        begin
          glEnable(GL_TEXTURE_2D);
          TexOn := True;
        end;
        if BoundTex <> N.Tex.Id then
        begin
          glBindTexture(GL_TEXTURE_2D, N.Tex.Id);
          BoundTex := N.Tex.Id;
        end;
        glColor4f(N.R * A, N.G * A, N.B * A, A);
        glBegin(GL_QUADS);
        glTexCoord2f(0, 0);
        Vtx(0, 0);
        glTexCoord2f(N.Tex.U, 0);
        Vtx(W, 0);
        glTexCoord2f(N.Tex.U, N.Tex.V);
        Vtx(W, H);
        glTexCoord2f(0, N.Tex.V);
        Vtx(0, H);
        glEnd;
      end;
    nkRect:
      begin
        if TexOn then
        begin
          glDisable(GL_TEXTURE_2D);
          TexOn := False;
        end;
        glColor4f(N.R * A, N.G * A, N.B * A, A);
        glBegin(GL_QUADS);
        Vtx(0, 0);
        Vtx(N.W, 0);
        Vtx(N.W, N.H);
        Vtx(0, N.H);
        glEnd;
      end;
  end;
  if N.Count = 0 then Exit;
  if N.HasClip then
  begin
    // the clipping rectangle is in this node's own coordinates (the nodes that clip are never rotated)
    X0 := M.A * N.ClipX + M.E;
    X1 := M.A * (N.ClipX + N.ClipW) + M.E;
    Y0 := M.D * N.ClipY + M.F;
    Y1 := M.D * (N.ClipY + N.ClipH) + M.F;
    if X1 < X0 then begin T := X0; X0 := X1; X1 := T; end;
    if Y1 < Y0 then begin T := Y0; Y0 := Y1; Y1 := T; end;
    C.On := True;
    C.X0 := X0;
    C.Y0 := Y0;
    C.X1 := X1;
    C.Y1 := Y1;
    if Clip.On then
    begin
      C.X0 := MaxF(C.X0, Clip.X0);
      C.Y0 := MaxF(C.Y0, Clip.Y0);
      C.X1 := Min(C.X1, Clip.X1);
      C.Y1 := Min(C.Y1, Clip.Y1);
    end;
    ApplyClip(C);
    for I := 0 to N.Count - 1 do DrawNode(N[I], M, A, C);
    ApplyClip(Clip);
  end
  else
    for I := 0 to N.Count - 1 do DrawNode(N[I], M, A, Clip);
end;

procedure DrawTree(Root: TNode; const View: TMat; ViewH, OriginX, OriginY: Integer);
var
  C: TClip;
begin
  DrawViewH := ViewH;
  DrawOX := OriginX;
  DrawOY := OriginY;
  BoundTex := 0;
  TexOn := False;
  glDisable(GL_TEXTURE_2D);
  glDisable(GL_SCISSOR_TEST);
  glEnable(GL_BLEND);
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);   // premultiplied alpha
  C.On := False;
  DrawNode(Root, View, 1, C);
  glDisable(GL_SCISSOR_TEST);
end;

{ ---------- TAnim ---------- }

procedure TAnim.Start;
begin
  Time := 0;
  Running := True;
  if Delay <= 0 then Apply(0);
end;

procedure TAnim.Stop;
begin
  Running := False;
end;

procedure TAnim.ClearTracks;
begin
  FTracks := nil;
end;

procedure TAnim.KeysF(Node: TNode; Field: TField; const Keys, Vals: array of Single);
var
  T: TTrack;
  I: Integer;
begin
  Assert(Length(Keys) = Length(Vals));
  T := Default(TTrack);
  T.Node := Node;
  T.Field := Field;
  T.Kind := tkKeys;
  SetLength(T.Keys, Length(Keys));
  SetLength(T.Vals, Length(Vals));
  for I := 0 to High(Keys) do
  begin
    T.Keys[I] := Keys[I];
    T.Vals[I] := V(Vals[I], 0);
  end;
  FTracks := FTracks + [T];
end;

procedure TAnim.KeysV(Node: TNode; Field: TField; const Keys: array of Single; const Vals: array of TVec2);
var
  T: TTrack;
  I: Integer;
begin
  Assert(Length(Keys) = Length(Vals));
  T := Default(TTrack);
  T.Node := Node;
  T.Field := Field;
  T.Kind := tkKeys;
  SetLength(T.Keys, Length(Keys));
  SetLength(T.Vals, Length(Vals));
  for I := 0 to High(Keys) do
  begin
    T.Keys[I] := Keys[I];
    T.Vals[I] := Vals[I];
  end;
  FTracks := FTracks + [T];
end;

procedure TAnim.SineF(Node: TNode; Field: TField; Center, Amp, Phase: Single);
begin
  SineV(Node, Field, V(Center, 0), V(Amp, 0), Phase);
end;

procedure TAnim.SineV(Node: TNode; Field: TField; const Base, Amp: TVec2; Phase: Single);
var
  T: TTrack;
begin
  T := Default(TTrack);
  T.Node := Node;
  T.Field := Field;
  T.Kind := tkSine;
  T.Base := Base;
  T.Amp := Amp;
  T.Phase := Phase;
  FTracks := FTracks + [T];
end;

procedure TAnim.Apply(F: Single);
var
  I, K, N: Integer;
  P: TVec2;
  S, U: Single;
begin
  case Ease of
    eOutQuad: F := 1 - (1 - F) * (1 - F);
    eInQuad: F := F * F;
  end;
  for I := 0 to High(FTracks) do
    with FTracks[I] do
    begin
      if Kind = tkSine then
      begin
        S := Sin(F * 2 * Pi + Phase);
        P.X := Base.X + Amp.X * S;
        P.Y := Base.Y + Amp.Y * S;
      end
      else
      begin
        N := Length(Keys);
        if N = 0 then Continue;
        if F <= Keys[0] then
          P := Vals[0]
        else if F >= Keys[N - 1] then
          P := Vals[N - 1]
        else
        begin
          K := 1;
          while (K < N - 1) and (Keys[K] < F) do Inc(K);
          if Keys[K] - Keys[K - 1] <= 0 then
            U := 1
          else
            U := (F - Keys[K - 1]) / (Keys[K] - Keys[K - 1]);
          P.X := Vals[K - 1].X + (Vals[K].X - Vals[K - 1].X) * U;
          P.Y := Vals[K - 1].Y + (Vals[K].Y - Vals[K - 1].Y) * U;
        end;
      end;
      case Field of
        fTranslation:
          begin
            Node.Tx := P.X;
            Node.Ty := P.Y;
          end;
        fRotation: Node.Rot := P.X;
        fScale:
          begin
            Node.Sx := P.X;
            Node.Sy := P.Y;
          end;
        fOpacity: Node.Opacity := P.X;
      end;
    end;
end;

{ ---------- TAnimator ---------- }

constructor TAnimator.Create;
begin
  FList := TObjectList<TAnim>.Create(True);
end;

destructor TAnimator.Destroy;
begin
  FList.Free;
  inherited;
end;

function TAnimator.New(Duration: Single; Loop: Boolean): TAnim;
begin
  Result := TAnim.Create;
  Result.Duration := Duration;
  Result.Loop := Loop;
  FList.Add(Result);
end;

function TAnimator.LoopF(Node: TNode; Field: TField; Center, Amp, Period, Phase: Single): TAnim;
begin
  Result := New(Period, True);
  Result.SineF(Node, Field, Center, Amp, Phase);
  Result.Start;
end;

function TAnimator.LoopV(Node: TNode; Field: TField; const Base, Amp: TVec2; Period, Phase: Single): TAnim;
begin
  Result := New(Period, True);
  Result.SineV(Node, Field, Base, Amp, Phase);
  Result.Start;
end;

{ The animation stops now and is freed after the current update; its nodes may be freed straight away }
procedure TAnimator.Kill(A: TAnim);
begin
  if A = nil then Exit;
  A.Running := False;
  A.Dead := True;
  A.OnDone := nil;
  A.ClearTracks;
end;

procedure TAnimator.Update(Dt: Single);
var
  I, N: Integer;
  A: TAnim;
  T: Single;
  Done: TProc;
begin
  N := FList.Count;   // animations added during this pass start on the next one
  for I := 0 to N - 1 do
  begin
    A := FList[I];
    if A.Dead or not A.Running then Continue;
    A.Time := A.Time + Dt;
    T := A.Time - A.Delay;
    if T < 0 then Continue;
    if A.Duration <= 0 then
      T := 1
    else
      T := T / A.Duration;
    if A.Loop then
      A.Apply(Frac(T))
    else if T >= 1 then
    begin
      A.Apply(1);
      A.Running := False;
      Done := A.OnDone;
      if Assigned(Done) then Done();
    end
    else
      A.Apply(T);
  end;
  for I := FList.Count - 1 downto 0 do
    if FList[I].Dead then FList.Delete(I);
end;

{ ---------- TTextureStore ---------- }

constructor TTextureStore.Create;
begin
  FMap := TObjectDictionary<string, TTexture>.Create([doOwnsValues]);
end;

destructor TTextureStore.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure TTextureStore.Init;
var
  Ver: string;
begin
  FReady := True;
  Ver := string(AnsiString(PAnsiChar(glGetString(GL_VERSION))));
  // OpenGL 2.0 and later take images of any size; the old software renderer needs powers of two
  FNPOT := StrToIntDef(Copy(Ver, 1, Pos('.', Ver) - 1), 1) >= 2;
  @FGenMipmap := wglGetProcAddress('glGenerateMipmap');
  if not Assigned(FGenMipmap) then @FGenMipmap := wglGetProcAddress('glGenerateMipmapEXT');
end;

function NextPow2(N: Integer): Integer;
begin
  Result := 1;
  while Result < N do Result := Result shl 1;
end;

{ Pixels: 32-bit BGRA, premultiplied alpha, top row first }
function TTextureStore.Upload(W, H: Integer; Pixels: Pointer; Mipmaps: Boolean): TTexture;
var
  TW, TH: Integer;
begin
  if not FReady then Init;
  Result := TTexture.Create;
  Result.W := W;
  Result.H := H;
  glGenTextures(1, @Result.Id);
  glBindTexture(GL_TEXTURE_2D, Result.Id);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  if FNPOT then
  begin
    Result.U := 1;
    Result.V := 1;
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_BGRA_EXT, GL_UNSIGNED_BYTE, Pixels);
    if Mipmaps and Assigned(FGenMipmap) then
    begin
      FGenMipmap(GL_TEXTURE_2D);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    end;
  end
  else
  begin
    TW := NextPow2(W);
    TH := NextPow2(H);
    Result.U := W / TW;
    Result.V := H / TH;
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, TW, TH, 0, GL_BGRA_EXT, GL_UNSIGNED_BYTE, nil);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, W, H, GL_BGRA_EXT, GL_UNSIGNED_BYTE, Pixels);
  end;
end;

var
  WicFactory: IWICImagingFactory;

{ Images are PNG resources named IMG_<NAME>, compiled in from ..\images\ocean (see ReefRes.rc) }
function TTextureStore.Get(const Name: string): TTexture;
var
  RS: TResourceStream;
  Stream: IStream;
  Decoder: IWICBitmapDecoder;
  Frame: IWICBitmapFrameDecode;
  Conv: IWICFormatConverter;
  W, H: Cardinal;
  Buf: TBytes;
begin
  if FMap.TryGetValue(Name, Result) then Exit;
  if WicFactory = nil then
    OleCheck(CoCreateInstance(CLSID_WICImagingFactory, nil, CLSCTX_INPROC_SERVER, IID_IWICImagingFactory, WicFactory));
  RS := TResourceStream.Create(HInstance, 'IMG_' + UpperCase(Name), RT_RCDATA);
  Stream := TStreamAdapter.Create(RS, soOwned);
  OleCheck(WicFactory.CreateDecoderFromStream(Stream, GUID_NULL, WICDecodeMetadataCacheOnDemand, Decoder));
  OleCheck(Decoder.GetFrame(0, Frame));
  OleCheck(WicFactory.CreateFormatConverter(Conv));
  OleCheck(Conv.Initialize(Frame, GUID_WICPixelFormat32bppPBGRA, WICBitmapDitherTypeNone, nil, 0, WICBitmapPaletteTypeCustom));
  OleCheck(Conv.GetSize(W, H));
  SetLength(Buf, W * H * 4);
  OleCheck(Conv.CopyPixels(nil, W * 4, Length(Buf), @Buf[0]));
  Result := Upload(W, H, @Buf[0], True);
  FMap.Add(Name, Result);
end;

function TTextureStore.MakeText(const Text, FontName: string; PixelHeight: Integer; Bold: Boolean): TTexture;
var
  Bmp: TBitmap;
  W, H, X, Y: Integer;
  P: PCardinal;
  A: Cardinal;
  Buf: TArray<Cardinal>;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.Canvas.Font.Name := FontName;
    Bmp.Canvas.Font.Height := -PixelHeight;
    if Bold then Bmp.Canvas.Font.Style := [fsBold];
    Bmp.Canvas.Font.Quality := fqAntialiased;
    Bmp.Canvas.Font.Color := clWhite;
    W := Max(1, Bmp.Canvas.TextWidth(Text) + 4);
    H := Max(1, Bmp.Canvas.TextHeight(Text));
    Bmp.SetSize(W, H);
    Bmp.Canvas.Brush.Color := clBlack;
    Bmp.Canvas.FillRect(Rect(0, 0, W, H));
    Bmp.Canvas.Brush.Style := bsClear;
    Bmp.Canvas.TextOut(2, 0, Text);
    SetLength(Buf, W * H);
    for Y := 0 to H - 1 do
    begin
      P := Bmp.ScanLine[Y];
      for X := 0 to W - 1 do
      begin
        // white on black: any colour channel is the coverage
        A := (P^ shr 8) and $FF;
        Buf[Y * W + X] := (A shl 24) or (A shl 16) or (A shl 8) or A;
        Inc(P);
      end;
    end;
    Result := Upload(W, H, @Buf[0], False);
  finally
    Bmp.Free;
  end;
end;

initialization
  Textures := TTextureStore.Create;

finalization
  FreeAndNil(Textures);
  WicFactory := nil;

end.
