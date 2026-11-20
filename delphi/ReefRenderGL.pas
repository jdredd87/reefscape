unit ReefRenderGL;

{ The OpenGL renderer of the VCL screensaver: images become textures, and every image is one tinted quad.
  Needs a current OpenGL context whenever an image is loaded or anything is drawn. }

interface

uses
  Winapi.Windows, Winapi.OpenGL, System.Types, System.SysUtils, System.Classes, System.Math,
  System.Generics.Collections, ReefEngine;

type
  TGLTexture = class(TTexture)
  public
    Id: GLuint;
    U, V: Single;       // texture coordinates of the image's right / bottom edge
    destructor Destroy; override;
  end;

  TGLRenderer = class(TReefRenderer)
  private
    FMap: TObjectDictionary<string, TGLTexture>;
    FReady, FNPOT: Boolean;
    FGenMipmap: procedure(Target: GLenum); stdcall;
    FBound: GLuint;
    FTexOn: Boolean;
    FOX, FOY, FViewH: Integer;
    procedure Init;
    function Upload(W, H: Integer; Pixels: Pointer; Mipmaps: Boolean): TGLTexture;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadImage(const Name: string): TTexture; override;
    function MakeText(const Text: string; PixelHeight: Integer; Bold: Boolean): TTexture; override;
    procedure BeginView(const ViewRect: TRect; WindowH: Integer; Color: Cardinal); override;
    procedure EndView; override;
    procedure DrawImage(Tex: TTexture; const M: TMat; W, H, R, G, B, A: Single); override;
    procedure FillRect(const M: TMat; W, H, R, G, B, A: Single); override;
    procedure SetClip(const Clip: TClip); override;
  end;

implementation

uses
  Winapi.ActiveX, Winapi.Wincodec, System.Win.ComObj, Vcl.Graphics;

const
  GL_BGRA_EXT = $80E1;
  GL_CLAMP_TO_EDGE = $812F;

var
  WicFactory: IWICImagingFactory;

{ ---------- TGLTexture ---------- }

destructor TGLTexture.Destroy;
begin
  if (Id <> 0) and (wglGetCurrentContext <> 0) then glDeleteTextures(1, @Id);
  inherited;
end;

{ ---------- TGLRenderer ---------- }

constructor TGLRenderer.Create;
begin
  FMap := TObjectDictionary<string, TGLTexture>.Create([doOwnsValues]);
end;

destructor TGLRenderer.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure TGLRenderer.Init;
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
function TGLRenderer.Upload(W, H: Integer; Pixels: Pointer; Mipmaps: Boolean): TGLTexture;
var
  TW, TH: Integer;
begin
  if not FReady then Init;
  Result := TGLTexture.Create;
  Result.W := W;
  Result.H := H;
  glGenTextures(1, @Result.Id);
  glBindTexture(GL_TEXTURE_2D, Result.Id);
  FBound := Result.Id;
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

{ Images are PNG resources named IMG_<NAME>, compiled in from ..\images\ocean (see ReefRes.rc) }
function TGLRenderer.LoadImage(const Name: string): TTexture;
var
  Tex: TGLTexture;
  RS: TResourceStream;
  Stream: IStream;
  Decoder: IWICBitmapDecoder;
  Frame: IWICBitmapFrameDecode;
  Conv: IWICFormatConverter;
  W, H: Cardinal;
  Buf: TBytes;
begin
  if FMap.TryGetValue(Name, Tex) then Exit(Tex);
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
  Tex := Upload(W, H, @Buf[0], True);
  FMap.Add(Name, Tex);
  Result := Tex;
end;

function TGLRenderer.MakeText(const Text: string; PixelHeight: Integer; Bold: Boolean): TTexture;
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
    Bmp.Canvas.Font.Name := 'Segoe UI';
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

procedure TGLRenderer.BeginView(const ViewRect: TRect; WindowH: Integer; Color: Cardinal);
begin
  // OpenGL counts window rows from the bottom
  FOX := ViewRect.Left;
  FOY := WindowH - ViewRect.Bottom;
  FViewH := ViewRect.Height;
  glViewport(FOX, FOY, ViewRect.Width, FViewH);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, ViewRect.Width, FViewH, 0, -1, 1);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  // clear this view only
  glEnable(GL_SCISSOR_TEST);
  glScissor(FOX, FOY, ViewRect.Width, FViewH);
  glClearColor(((Color shr 16) and $FF) / 255, ((Color shr 8) and $FF) / 255, (Color and $FF) / 255, 1);
  glClear(GL_COLOR_BUFFER_BIT);
  glDisable(GL_SCISSOR_TEST);
  glDisable(GL_TEXTURE_2D);
  FTexOn := False;
  FBound := 0;
  glEnable(GL_BLEND);
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);   // premultiplied alpha
end;

procedure TGLRenderer.EndView;
begin
  glDisable(GL_SCISSOR_TEST);
end;

procedure TGLRenderer.SetClip(const Clip: TClip);
var
  X, Y, W, H: Integer;
begin
  if not Clip.On then
  begin
    glDisable(GL_SCISSOR_TEST);
    Exit;
  end;
  X := Floor(Clip.X0);
  Y := Floor(Clip.Y0);
  W := Max(0, Ceil(Clip.X1) - X);
  H := Max(0, Ceil(Clip.Y1) - Y);
  glEnable(GL_SCISSOR_TEST);
  glScissor(FOX + X, FOY + FViewH - (Y + H), W, H);
end;

procedure TGLRenderer.DrawImage(Tex: TTexture; const M: TMat; W, H, R, G, B, A: Single);
var
  T: TGLTexture;
begin
  T := TGLTexture(Tex);
  if not FTexOn then
  begin
    glEnable(GL_TEXTURE_2D);
    FTexOn := True;
  end;
  if FBound <> T.Id then
  begin
    glBindTexture(GL_TEXTURE_2D, T.Id);
    FBound := T.Id;
  end;
  glColor4f(R * A, G * A, B * A, A);
  glBegin(GL_QUADS);
  glTexCoord2f(0, 0);
  glVertex2f(M.E, M.F);
  glTexCoord2f(T.U, 0);
  glVertex2f(M.A * W + M.E, M.B * W + M.F);
  glTexCoord2f(T.U, T.V);
  glVertex2f(M.A * W + M.C * H + M.E, M.B * W + M.D * H + M.F);
  glTexCoord2f(0, T.V);
  glVertex2f(M.C * H + M.E, M.D * H + M.F);
  glEnd;
end;

procedure TGLRenderer.FillRect(const M: TMat; W, H, R, G, B, A: Single);
begin
  if FTexOn then
  begin
    glDisable(GL_TEXTURE_2D);
    FTexOn := False;
  end;
  glColor4f(R * A, G * A, B * A, A);
  glBegin(GL_QUADS);
  glVertex2f(M.E, M.F);
  glVertex2f(M.A * W + M.E, M.B * W + M.F);
  glVertex2f(M.A * W + M.C * H + M.E, M.B * W + M.D * H + M.F);
  glVertex2f(M.C * H + M.E, M.D * H + M.F);
  glEnd;
end;

initialization
  Renderer := TGLRenderer.Create;

finalization
  FreeAndNil(Renderer);
  WicFactory := nil;

end.
