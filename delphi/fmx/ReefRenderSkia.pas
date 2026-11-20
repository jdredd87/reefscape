unit ReefRenderSkia;

{ The Skia renderer of the FMX app. Each image is drawn with Skia's canvas, tinted with a colour filter.
  The form hands over the canvas for the length of one frame (Canvas property). Works on every FMX platform. }

interface

uses
  System.Types, System.UITypes, System.SysUtils, System.Classes, System.Math, System.Math.Vectors,
  System.Generics.Collections, System.Skia, ReefEngine;

type
  TSkTexture = class(TTexture)
  public
    Image: ISkImage;
  end;

  TSkiaRenderer = class(TReefRenderer)
  private
    FMap: TObjectDictionary<string, TSkTexture>;
    FFilters: TDictionary<Cardinal, ISkColorFilter>;
    FCanvas: ISkCanvas;
    FPaint, FFill: ISkPaint;
    FSampling: TSkSamplingOptions;
    FClipOn: Boolean;
    function Tint(R, G, B: Single): ISkColorFilter;
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
    { the canvas to draw on, in device pixels; set it before the scene's Render and clear it after }
    property Canvas: ISkCanvas read FCanvas write FCanvas;
  end;

function SkiaRenderer: TSkiaRenderer;

implementation

function SkiaRenderer: TSkiaRenderer;
begin
  Result := TSkiaRenderer(Renderer);
end;

function ToMatrix(const M: TMat): TMatrix;
begin
  Result.m11 := M.A;
  Result.m12 := M.B;
  Result.m13 := 0;
  Result.m21 := M.C;
  Result.m22 := M.D;
  Result.m23 := 0;
  Result.m31 := M.E;
  Result.m32 := M.F;
  Result.m33 := 1;
end;

constructor TSkiaRenderer.Create;
begin
  FMap := TObjectDictionary<string, TSkTexture>.Create([doOwnsValues]);
  FFilters := TDictionary<Cardinal, ISkColorFilter>.Create;
  FPaint := TSkPaint.Create;
  FFill := TSkPaint.Create;
  // smooth when enlarged, and no shimmer when a far-away animal is drawn small
  FSampling := TSkSamplingOptions.Create(TSkFilterMode.Linear, TSkMipmapMode.Linear);
end;

destructor TSkiaRenderer.Destroy;
begin
  FFilters.Free;
  FMap.Free;
  inherited;
end;

{ Images are PNG resources named IMG_<NAME>, compiled in from ..\..\images\ocean (see ReefImages.rc) }
function TSkiaRenderer.LoadImage(const Name: string): TTexture;
var
  Tex: TSkTexture;
  RS: TResourceStream;
  Img: ISkImage;
begin
  if FMap.TryGetValue(Name, Tex) then Exit(Tex);
  RS := TResourceStream.Create(HInstance, 'IMG_' + UpperCase(Name), RT_RCDATA);
  try
    Img := TSkImage.MakeFromEncodedStream(RS);
  finally
    RS.Free;
  end;
  if Img = nil then raise Exception.Create('Cannot read image ' + Name);
  Tex := TSkTexture.Create;
  // decoded once, now: an encoded image would be decoded again whenever Skia's cache dropped it
  Tex.Image := Img.MakeRasterImage;
  if Tex.Image = nil then Tex.Image := Img;
  Tex.W := Tex.Image.Width;
  Tex.H := Tex.Image.Height;
  FMap.Add(Name, Tex);
  Result := Tex;
end;

function TSkiaRenderer.MakeText(const Text: string; PixelHeight: Integer; Bold: Boolean): TTexture;
var
  Face: ISkTypeface;
  Font: ISkFont;
  Met: TSkFontMetrics;
  Surf: ISkSurface;
  Paint: ISkPaint;
  Style: TSkFontStyle;
  W, H: Integer;
  Tex: TSkTexture;
begin
  if Bold then Style := TSkFontStyle.Bold else Style := TSkFontStyle.Normal;
  Face := TSkTypeface.MakeFromName({$IFDEF MSWINDOWS}'Segoe UI'{$ELSE}''{$ENDIF}, Style);
  if Face = nil then Face := TSkTypeface.MakeDefault;
  Font := TSkFont.Create(Face, PixelHeight);
  Font.GetMetrics(Met);
  W := Max(1, Ceil(Font.MeasureText(Text)) + 4);
  H := Max(1, Ceil(Met.Descent - Met.Ascent));
  Surf := TSkSurface.MakeRaster(W, H);
  Surf.Canvas.Clear(TAlphaColors.Null);
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Color := TAlphaColors.White;
  Surf.Canvas.DrawSimpleText(Text, 2, -Met.Ascent, Font, Paint);
  Tex := TSkTexture.Create;
  Tex.Image := Surf.MakeImageSnapshot;
  Tex.W := W;
  Tex.H := H;
  Result := Tex;
end;

{ a filter that multiplies an image by a colour (how the reef tints far-away animals blue) }
function TSkiaRenderer.Tint(R, G, B: Single): ISkColorFilter;
var
  Key: Cardinal;
begin
  Key := (Cardinal(EnsureRange(Round(R * 255), 0, 255)) shl 16) or (Cardinal(EnsureRange(Round(G * 255), 0, 255)) shl 8) or
    Cardinal(EnsureRange(Round(B * 255), 0, 255));
  if Key = $FFFFFF then Exit(nil);
  if not FFilters.TryGetValue(Key, Result) then
  begin
    if FFilters.Count > 400 then FFilters.Clear;
    Result := TSkColorFilter.MakeBlend(TAlphaColor($FF000000 or Key), TSkBlendMode.Modulate);
    FFilters.Add(Key, Result);
  end;
end;

procedure TSkiaRenderer.BeginView(const ViewRect: TRect; WindowH: Integer; Color: Cardinal);
begin
  FCanvas.Save;
  FCanvas.ClipRect(TRectF.Create(ViewRect));
  FCanvas.Translate(ViewRect.Left, ViewRect.Top);
  FCanvas.Clear(TAlphaColor($FF000000 or Color));
  FClipOn := False;
end;

procedure TSkiaRenderer.EndView;
begin
  if FClipOn then FCanvas.Restore;
  FClipOn := False;
  FCanvas.Restore;
end;

{ the engine always passes the whole clip (already cut down to its parents'), so one level is enough }
procedure TSkiaRenderer.SetClip(const Clip: TClip);
begin
  if FClipOn then FCanvas.Restore;
  FClipOn := Clip.On;
  if Clip.On then
  begin
    FCanvas.Save;
    FCanvas.ClipRect(TRectF.Create(Floor(Clip.X0), Floor(Clip.Y0), Ceil(Clip.X1), Ceil(Clip.Y1)));
  end;
end;

procedure TSkiaRenderer.DrawImage(Tex: TTexture; const M: TMat; W, H, R, G, B, A: Single);
begin
  FCanvas.Save;
  FCanvas.Concat(ToMatrix(M));
  FPaint.AlphaF := A;
  FPaint.ColorFilter := Tint(R, G, B);
  FCanvas.DrawImageRect(TSkTexture(Tex).Image, TRectF.Create(0, 0, W, H), FSampling, FPaint);
  FCanvas.Restore;
end;

procedure TSkiaRenderer.FillRect(const M: TMat; W, H, R, G, B, A: Single);
begin
  FCanvas.Save;
  FCanvas.Concat(ToMatrix(M));
  FFill.Color := TAlphaColorF.Create(R, G, B, A).ToAlphaColor;
  FCanvas.DrawRect(TRectF.Create(0, 0, W, H), FFill);
  FCanvas.Restore;
end;

initialization
  Renderer := TSkiaRenderer.Create;

finalization
  FreeAndNil(Renderer);

end.
