unit KLineChart;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Controls,
  Vcl.Graphics, System.Types, System.Math, Winapi.GDIPOBJ, Winapi.GDIPAPI,
  System.Generics.Collections;

type
  // K线数据结构
  TKLineData = record
    DateTime: TDateTime;
    Open: Double;
    High: Double;
    Low: Double;
    Close: Double;
    Volume: Int64;
  end;

  // 移动平均线数据
  TMAData = record
    MA5: Double;
    MA10: Double;
  end;

  // 锚点数据结构
  TAnchorPoint = record
    Index: Integer; // K线索引
    Price: Double; // 价格
    AnchorType: Integer; // 锚点类型：1=MA5, 2=MA10
    DateTime: TDateTime; // 时间
  end;

  // 鼠标信息提示数据
  TTooltipData = record
    Visible: Boolean;
    X, Y: Integer;
    KLineIndex: Integer;
    KLineData: TKLineData;
    MAData: TMAData;
  end;

  TKLineChart = class(TCustomControl)
  private
    FKLineDataList: TList<TKLineData>;
    FMADataList: TList<TMAData>;
    FAnchorPoints: TList<TAnchorPoint>;
    FBitmap: TBitmap;
    FGPGraphics: TGPGraphics;
    FGPBitmap: TGPBitmap;
    FGPGraphicsBuffer: TGPGraphics;

    // 显示参数
    FStartIndex: Integer;
    FVisibleCount: Integer;
    FKLineWidth: Integer;
    FKLineSpacing: Integer;
    FScaleFactor: Double;

    // 价格范围
    FMaxPrice: Double;
    FMinPrice: Double;

    // 鼠标操作
    FMouseDown: Boolean;
    FLastMousePos: TPoint;
    FTooltip: TTooltipData;

    // 颜色定义
    FUpColor: TGPColor;
    FDownColor: TGPColor;
    FMA5Color: TGPColor;
    FMA10Color: TGPColor;
    FGridColor: TGPColor;
    FTextColor: TGPColor;
    FBackgroundColor: TGPColor;
    FAnchorColor: TGPColor;

    // 可重用的GDI+对象，避免频繁创建销毁
    FUpBrush: TGPSolidBrush;
    FDownBrush: TGPSolidBrush;
    FUpPen: TGPPen;
    FDownPen: TGPPen;
    FMA5Pen: TGPPen;
    FMA10Pen: TGPPen;
    FGridPen: TGPPen;
    FBackgroundBrush: TGPSolidBrush;
    FTextBrush: TGPSolidBrush;
    FAnchorBrush: TGPSolidBrush;
    FAnchorPen: TGPPen;
    FTooltipBackBrush: TGPSolidBrush;
    FTooltipBorderPen: TGPPen;

    procedure InitializeGDIPlus;
    procedure FinalizeGDIPlus;
    procedure CreateBuffer;
    procedure CalculateVisibleRange;
    procedure CalculatePriceRange;
    procedure CalculateMovingAverages;
    procedure DrawBackground;
    procedure DrawGrid;
    procedure DrawKLines;
    procedure DrawMovingAverages;
    procedure DrawAnchorPoints;
    procedure DrawTooltip;
    procedure DrawPriceScale;
    procedure DrawTimeScale;
    function IsPointNearMA(X, Y: Integer; out MAType: Integer;
      out Index: Integer): Boolean;
    procedure AddAnchorPoint(Index: Integer; MAType: Integer);
    procedure ClearAnchorPoints;
    function PriceToY(Price: Double): Integer;
    function IndexToX(Index: Integer): Integer;
    function XToIndex(X: Integer): Integer;
    function GetKLineRect(Index: Integer): TRect;

  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddKLineData(const AData: TKLineData);
    procedure ClearData;
    procedure Refresh;
  end;

implementation

{ TKLineChart }

constructor TKLineChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  DoubleBuffered := true;

  FKLineDataList := TList<TKLineData>.Create;
  FMADataList := TList<TMAData>.Create;
  FAnchorPoints := TList<TAnchorPoint>.Create;

  // 初始化参数
  FStartIndex := 0;
  FVisibleCount := 100;
  FKLineWidth := 6;
  FKLineSpacing := 2;
  FScaleFactor := 1.0;

  // 初始化颜色
  FUpColor := MakeColor(255, 210, 41, 41); // 上涨
  FDownColor := MakeColor(255, 84, 252, 252); // 下跌
  FMA5Color := MakeColor(255, 255, 255, 0); // 黄色 - MA5
  FMA10Color := MakeColor(255, 255, 0, 255); // 紫色 - MA10
  FGridColor := MakeColor(100, 128, 128, 128); // 灰色网格
  FTextColor := MakeColor(255, 255, 255, 255); // 白色文字
  FBackgroundColor := MakeColor(255, 0, 0, 0); // 黑色背景
  FAnchorColor := MakeColor(255, 255, 165, 0); // 橙色锚点

  FTooltip.Visible := False;

  // 创建可重用的GDI+对象
  FUpBrush := TGPSolidBrush.Create(FUpColor);
  FDownBrush := TGPSolidBrush.Create(FDownColor);
  FUpPen := TGPPen.Create(FUpColor, 1);
  FDownPen := TGPPen.Create(FDownColor, 1);
  FMA5Pen := TGPPen.Create(FMA5Color, 2);
  FMA10Pen := TGPPen.Create(FMA10Color, 2);
  FGridPen := TGPPen.Create(FGridColor, 1);
  FBackgroundBrush := TGPSolidBrush.Create(FBackgroundColor);
  FTextBrush := TGPSolidBrush.Create(FTextColor);
  FAnchorBrush := TGPSolidBrush.Create(FAnchorColor);
  FAnchorPen := TGPPen.Create(FAnchorColor, 2);
  FTooltipBackBrush := TGPSolidBrush.Create(MakeColor(200, 0, 0, 0));
  FTooltipBorderPen := TGPPen.Create(FTextColor, 1);

  InitializeGDIPlus;

  Width := 800;
  Height := 600;
end;

destructor TKLineChart.Destroy;
begin
  // 释放可重用的GDI+对象
  if Assigned(FUpBrush) then
    FUpBrush.Free;
  if Assigned(FDownBrush) then
    FDownBrush.Free;
  if Assigned(FUpPen) then
    FUpPen.Free;
  if Assigned(FDownPen) then
    FDownPen.Free;
  if Assigned(FMA5Pen) then
    FMA5Pen.Free;
  if Assigned(FMA10Pen) then
    FMA10Pen.Free;
  if Assigned(FGridPen) then
    FGridPen.Free;
  if Assigned(FBackgroundBrush) then
    FBackgroundBrush.Free;
  if Assigned(FTextBrush) then
    FTextBrush.Free;
  if Assigned(FAnchorBrush) then
    FAnchorBrush.Free;
  if Assigned(FAnchorPen) then
    FAnchorPen.Free;
  if Assigned(FTooltipBackBrush) then
    FTooltipBackBrush.Free;
  if Assigned(FTooltipBorderPen) then
    FTooltipBorderPen.Free;

  FinalizeGDIPlus;
  FKLineDataList.Free;
  FMADataList.Free;
  FAnchorPoints.Free;
  inherited Destroy;
end;

procedure TKLineChart.InitializeGDIPlus;
begin
  FBitmap := TBitmap.Create;
  FBitmap.PixelFormat := pf32bit;
  CreateBuffer;
end;

procedure TKLineChart.FinalizeGDIPlus;
begin
  if Assigned(FGPGraphicsBuffer) then
    FGPGraphicsBuffer.Free;
  if Assigned(FGPBitmap) then
    FGPBitmap.Free;
  if Assigned(FGPGraphics) then
    FGPGraphics.Free;
  if Assigned(FBitmap) then
    FBitmap.Free;
end;

procedure TKLineChart.CreateBuffer;
begin
  if (Width <= 0) or (Height <= 0) then
    Exit;

  FBitmap.Width := Width;
  FBitmap.Height := Height;

  if Assigned(FGPGraphicsBuffer) then
    FGPGraphicsBuffer.Free;
  if Assigned(FGPBitmap) then
    FGPBitmap.Free;
  if Assigned(FGPGraphics) then
    FGPGraphics.Free;

  FGPBitmap := TGPBitmap.Create(Width, Height, PixelFormat32bppARGB);
  FGPGraphicsBuffer := TGPGraphics.Create(FGPBitmap);
  FGPGraphicsBuffer.SetSmoothingMode(SmoothingModeAntiAlias);
  FGPGraphicsBuffer.SetTextRenderingHint(TextRenderingHintAntiAlias);

  FGPGraphics := TGPGraphics.Create(FBitmap.Canvas.Handle);
end;

procedure TKLineChart.Resize;
begin
  inherited Resize;
  CreateBuffer;
  CalculateVisibleRange;
  Invalidate;
end;

procedure TKLineChart.AddKLineData(const AData: TKLineData);
var
  MAData: TMAData;
begin
  FKLineDataList.Add(AData);

  // 计算移动平均线
  MAData.MA5 := 0;
  MAData.MA10 := 0;
  FMADataList.Add(MAData);

  CalculateMovingAverages;
  CalculateVisibleRange;
  FStartIndex := Max(FKLineDataList.Count - FVisibleCount, 0);
end;

procedure TKLineChart.ClearData;
begin
  FKLineDataList.Clear;
  FMADataList.Clear;
  FAnchorPoints.Clear;
  FStartIndex := 0;
  Invalidate;
end;

procedure TKLineChart.CalculateVisibleRange;
var
  TotalWidth: Integer;
begin
  if FKLineDataList.Count = 0 then
    Exit;

  TotalWidth := Width - 100; // 留出价格刻度空间
  FVisibleCount := Round(TotalWidth / ((FKLineWidth + FKLineSpacing) *
    FScaleFactor));

  if FVisibleCount > FKLineDataList.Count then
    FVisibleCount := FKLineDataList.Count;

  if FStartIndex + FVisibleCount > FKLineDataList.Count then
    FStartIndex := FKLineDataList.Count - FVisibleCount;

  if FStartIndex < 0 then
    FStartIndex := 0;
end;

procedure TKLineChart.CalculatePriceRange;
var
  I: Integer;
  KLineData: TKLineData;
  PriceRange: Double;
begin
  if FKLineDataList.Count = 0 then
    Exit;

  FMaxPrice := -MaxDouble;
  FMinPrice := MaxDouble;

  for I := FStartIndex to Min(FStartIndex + FVisibleCount - 1,
    FKLineDataList.Count - 1) do
  begin
    KLineData := FKLineDataList[I];
    if KLineData.High > FMaxPrice then
      FMaxPrice := KLineData.High;
    if KLineData.Low < FMinPrice then
      FMinPrice := KLineData.Low;
  end;

  // 添加一些边距
  PriceRange := FMaxPrice - FMinPrice;
  FMaxPrice := FMaxPrice + PriceRange * 0.1;
  FMinPrice := FMinPrice - PriceRange * 0.1;
end;

procedure TKLineChart.CalculateMovingAverages;
var
  I, J: Integer;
  Sum5, Sum10: Double;
  Count5, Count10: Integer;
  MAData: TMAData;
begin
  for I := 0 to FKLineDataList.Count - 1 do
  begin
    // 计算MA5
    Sum5 := 0;
    Count5 := 0;
    for J := Max(0, I - 4) to I do
    begin
      Sum5 := Sum5 + FKLineDataList[J].Close;
      Inc(Count5);
    end;

    // 计算MA10
    Sum10 := 0;
    Count10 := 0;
    for J := Max(0, I - 9) to I do
    begin
      Sum10 := Sum10 + FKLineDataList[J].Close;
      Inc(Count10);
    end;

    MAData.MA5 := Sum5 / Count5;
    MAData.MA10 := Sum10 / Count10;

    if I < FMADataList.Count then
      FMADataList[I] := MAData
    else
      FMADataList.Add(MAData);
  end;
end;

function TKLineChart.PriceToY(Price: Double): Integer;
var
  ChartHeight: Integer;
begin
  ChartHeight := Height - 60; // 留出时间刻度空间
  if FMaxPrice = FMinPrice then
    Result := ChartHeight div 2
  else
    Result := Round(30 + (FMaxPrice - Price) / (FMaxPrice - FMinPrice) *
      (ChartHeight - 60));
end;

function TKLineChart.IndexToX(Index: Integer): Integer;
var
  RelativeIndex: Integer;
begin
  RelativeIndex := Index - FStartIndex;
  Result := 50 + Round(RelativeIndex * (FKLineWidth + FKLineSpacing) *
    FScaleFactor);
end;

function TKLineChart.XToIndex(X: Integer): Integer;
begin
  Result := FStartIndex +
    Round((X - 50) / ((FKLineWidth + FKLineSpacing) * FScaleFactor));
  if Result < 0 then
    Result := 0;
  if Result >= FKLineDataList.Count then
    Result := FKLineDataList.Count - 1;
end;

function TKLineChart.GetKLineRect(Index: Integer): TRect;
var
  X: Integer;
  KLineData: TKLineData;
  OpenY, CloseY: Integer;
begin
  X := IndexToX(Index);
  KLineData := FKLineDataList[Index];

  OpenY := PriceToY(KLineData.Open);
  CloseY := PriceToY(KLineData.Close);

  Result.Left := X - Round(FKLineWidth * FScaleFactor / 2);
  Result.Right := X + Round(FKLineWidth * FScaleFactor / 2);
  Result.Top := Min(OpenY, CloseY);
  Result.Bottom := Max(OpenY, CloseY);

  if Result.Top = Result.Bottom then
    Result.Bottom := Result.Top + 1;
end;

procedure TKLineChart.DrawBackground;
begin
  FGPGraphicsBuffer.FillRectangle(FBackgroundBrush, 0, 0, Width, Height);
end;

procedure TKLineChart.DrawGrid;
var
  I: Integer;
  X: Integer;
  Y: Integer;
  PriceStep: Double;
  Price: Double;
begin
  // 绘制水平网格线
  if FMaxPrice > FMinPrice then
  begin
    PriceStep := (FMaxPrice - FMinPrice) / 10;
    for I := 0 to 10 do
    begin
      Price := FMinPrice + I * PriceStep;
      Y := PriceToY(Price);
      FGPGraphicsBuffer.DrawLine(FGridPen, 50, Y, Width - 50, Y);
    end;
  end;

  // 绘制垂直网格线
  for I := 0 to FVisibleCount - 1 do
  begin
    if (FStartIndex + I) mod 10 = 0 then
    begin
      X := IndexToX(FStartIndex + I);
      FGPGraphicsBuffer.DrawLine(FGridPen, X, 30, X, Height - 30);
    end;
  end;
end;

procedure TKLineChart.DrawKLines;
var
  I: Integer;
  KLineData: TKLineData;
  X, HighY, LowY: Integer;
  KLineRect: TRect;
  IsUp: Boolean;
begin
  for I := FStartIndex to Min(FStartIndex + FVisibleCount - 1,
    FKLineDataList.Count - 1) do
  begin
    KLineData := FKLineDataList[I];
    IsUp := KLineData.Close >= KLineData.Open;

    X := IndexToX(I);
    HighY := PriceToY(KLineData.High);
    LowY := PriceToY(KLineData.Low);
    KLineRect := GetKLineRect(I);

    // 绘制上下影线
    if IsUp then
    begin
      FGPGraphicsBuffer.DrawLine(FUpPen, X, HighY, X, KLineRect.Top);
      FGPGraphicsBuffer.DrawLine(FUpPen, X, KLineRect.Bottom, X, LowY);
    end
    else
    begin
      FGPGraphicsBuffer.DrawLine(FDownPen, X, HighY, X, KLineRect.Top);
      FGPGraphicsBuffer.DrawLine(FDownPen, X, KLineRect.Bottom, X, LowY);
    end;

    // 绘制实体

    if IsUp then
    begin
      // 上涨：空心矩形
      FGPGraphicsBuffer.DrawRectangle(FUpPen, KLineRect.Left, KLineRect.Top,
        KLineRect.Right - KLineRect.Left, KLineRect.Bottom - KLineRect.Top);
    end
    else
    begin
      // 下跌：实心矩形
      FGPGraphicsBuffer.FillRectangle(FDownBrush, KLineRect.Left, KLineRect.Top,
        KLineRect.Right - KLineRect.Left, KLineRect.Bottom - KLineRect.Top);
    end;
  end;
end;

procedure TKLineChart.DrawMovingAverages;
var
  I: Integer;
  X1, Y1, X2, Y2: Integer;
begin
  if FMADataList.Count < 2 then
    Exit;

  for I := FStartIndex to Min(FStartIndex + FVisibleCount - 2,
    FKLineDataList.Count - 2) do
  begin
    X1 := IndexToX(I);
    X2 := IndexToX(I + 1);

    // 绘制MA5
    if (I < FMADataList.Count) and (I + 1 < FMADataList.Count) then
    begin
      Y1 := PriceToY(FMADataList[I].MA5);
      Y2 := PriceToY(FMADataList[I + 1].MA5);
      FGPGraphicsBuffer.DrawLine(FMA5Pen, X1, Y1, X2, Y2);
    end;

    // 绘制MA10
    if (I < FMADataList.Count) and (I + 1 < FMADataList.Count) then
    begin
      Y1 := PriceToY(FMADataList[I].MA10);
      Y2 := PriceToY(FMADataList[I + 1].MA10);
      FGPGraphicsBuffer.DrawLine(FMA10Pen, X1, Y1, X2, Y2);
    end;
  end;
end;

procedure TKLineChart.DrawPriceScale;
var
  Font: TGPFont;
  I: Integer;
  Y: Integer;
  PriceStep: Double;
  Price: Double;
  PriceText: string;
  StringFormat: TGPStringFormat;
begin
  Font := TGPFont.Create('Arial', 10);
  StringFormat := TGPStringFormat.Create;
  StringFormat.SetAlignment(StringAlignmentNear);

  try
    if FMaxPrice > FMinPrice then
    begin
      PriceStep := (FMaxPrice - FMinPrice) / 10;
      for I := 0 to 10 do
      begin
        Price := FMinPrice + I * PriceStep;
        Y := PriceToY(Price);
        PriceText := FormatFloat('0.00', Price);
        FGPGraphicsBuffer.DrawString(PriceText, -1, Font,
          MakePoint(Single(Width - 45), Single(Y - 8)), FTextBrush);
      end;
    end;
  finally
    Font.Free;
    StringFormat.Free;
  end;
end;

procedure TKLineChart.DrawTimeScale;
var
  Font: TGPFont;
  I: Integer;
  X: Integer;
  TimeText: string;
  StringFormat: TGPStringFormat;
begin
  Font := TGPFont.Create('Arial', 10);
  StringFormat := TGPStringFormat.Create;
  StringFormat.SetAlignment(StringAlignmentCenter);

  try
    for I := FStartIndex to Min(FStartIndex + FVisibleCount - 1,
      FKLineDataList.Count - 1) do
    begin
      if (I - FStartIndex) mod 20 = 0 then
      begin
        X := IndexToX(I);
        TimeText := FormatDateTime('mm-dd hh:nn', FKLineDataList[I].DateTime);
        FGPGraphicsBuffer.DrawString(TimeText, -1, Font,
          MakePoint(Single(X - 30), Single(Height - 25)), FTextBrush);
      end;
    end;
  finally
    Font.Free;
    StringFormat.Free;
  end;
end;

procedure TKLineChart.DrawTooltip;
var
  Font: TGPFont;
  StringFormat: TGPStringFormat;
  TooltipText: string;
  TooltipRect: TGPRectF;
begin
  if not FTooltip.Visible then
    Exit;

  Font := TGPFont.Create('Arial', 10);
  StringFormat := TGPStringFormat.Create;

  try
    TooltipText :=
      Format('时间: %s'#13#10'开盘: %.2f'#13#10'最高: %.2f'#13#10'最低: %.2f'#13#10'收盘: %.2f'#13#10'MA5: %.2f'#13#10'MA10: %.2f',
      [FormatDateTime('yyyy-mm-dd hh:nn', FTooltip.KLineData.DateTime),
      FTooltip.KLineData.Open, FTooltip.KLineData.High, FTooltip.KLineData.Low,
      FTooltip.KLineData.Close, FTooltip.MAData.MA5, FTooltip.MAData.MA10]);

    TooltipRect := Winapi.GDIPAPI.MakeRect(Single(FTooltip.X + 10),
      Single(FTooltip.Y + 10), Single(150), Single(120));

    // 确保提示框不超出边界
    if TooltipRect.X + TooltipRect.Width > Width then
      TooltipRect.X := FTooltip.X - TooltipRect.Width - 10;
    if TooltipRect.Y + TooltipRect.Height > Height then
      TooltipRect.Y := FTooltip.Y - TooltipRect.Height - 10;

    // 绘制背景
    FGPGraphicsBuffer.FillRectangle(FTooltipBackBrush, TooltipRect);
    FGPGraphicsBuffer.DrawRectangle(FTooltipBorderPen, TooltipRect);

    // 绘制文字
    FGPGraphicsBuffer.DrawString(TooltipText, -1, Font, TooltipRect,
      StringFormat, FTextBrush);
  finally
    Font.Free;
    StringFormat.Free;
  end;
end;

procedure TKLineChart.Paint;
var
  Graphics: TGPGraphics;
begin
  if not Assigned(FGPGraphicsBuffer) then
    Exit;

  CalculatePriceRange;

  // 清空缓冲区
  DrawBackground;

  // 绘制各个组件
  DrawGrid;
  DrawKLines;
  DrawMovingAverages;
  DrawAnchorPoints;
  DrawPriceScale;
  DrawTimeScale;
  DrawTooltip;

  // 将缓冲区内容复制到屏幕

  Graphics := TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.DrawImage(FGPBitmap, 0, 0);
  finally
    Graphics.Free;
  end;
end;

procedure TKLineChart.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  MAType, Index: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);

  if Button = mbLeft then
  begin
    // 检查是否点击了移动平均线
    if IsPointNearMA(X, Y, MAType, Index) then
    begin
      // 点击了移动平均线，添加锚点
      AddAnchorPoint(Index, MAType);
      Invalidate;
    end
    else
    begin
      // 普通拖动操作
      FMouseDown := true;
      FLastMousePos := Point(X, Y);
      SetCapture(Handle);
    end;
  end;
end;

procedure TKLineChart.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Index: Integer;
  DeltaX: Integer;
  IndexDelta: Integer;
begin
  inherited MouseMove(Shift, X, Y);

  // 处理拖动
  if FMouseDown and (ssLeft in Shift) then
  begin
    DeltaX := X - FLastMousePos.X;
    IndexDelta := Round(DeltaX / ((FKLineWidth + FKLineSpacing) *
      FScaleFactor));

    FStartIndex := FStartIndex - IndexDelta;
    if FStartIndex < 0 then
      FStartIndex := 0;
    if FStartIndex + FVisibleCount > FKLineDataList.Count then
      FStartIndex := FKLineDataList.Count - FVisibleCount;

    FLastMousePos := Point(X, Y);
    Invalidate;
  end
  else
  begin
    // 处理悬停提示
    Index := XToIndex(X);
    if (Index >= 0) and (Index < FKLineDataList.Count) and
      (Index < FMADataList.Count) then
    begin
      FTooltip.Visible := true;
      FTooltip.X := X;
      FTooltip.Y := Y;
      FTooltip.KLineIndex := Index;
      FTooltip.KLineData := FKLineDataList[Index];
      FTooltip.MAData := FMADataList[Index];
      Invalidate;
    end
    else
    begin
      FTooltip.Visible := False;
      Invalidate;
    end;
  end;
end;

procedure TKLineChart.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);

  if Button = mbLeft then
  begin
    FMouseDown := False;
    ReleaseCapture;
  end;
end;

function TKLineChart.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  inherited DoMouseWheel(Shift, WheelDelta, MousePos);

  if WheelDelta > 0 then
  begin
    // 向上滚动 - 放大
    FScaleFactor := FScaleFactor * 1.1;
    if FScaleFactor > 5.0 then
      FScaleFactor := 5.0;
  end
  else
  begin
    // 向下滚动 - 缩小
    FScaleFactor := FScaleFactor * 0.9;
    if FScaleFactor < 0.1 then
      FScaleFactor := 0.1;
  end;

  CalculateVisibleRange;
  Invalidate;
  Result := true;
end;

procedure TKLineChart.Refresh;
begin
  CalculateMovingAverages;
  CalculateVisibleRange;
  Invalidate;
end;

function TKLineChart.IsPointNearMA(X, Y: Integer; out MAType: Integer;
  out Index: Integer): Boolean;
var
  I: Integer;
  X1, Y1, X2, Y2: Integer;
  Distance: Double;
const
  CLICK_TOLERANCE = 5; // 点击容差像素
begin
  Result := False;
  MAType := 0;
  Index := -1;

  if FMADataList.Count < 2 then
    Exit;

  // 检查每一段移动平均线
  for I := FStartIndex to Min(FStartIndex + FVisibleCount - 2,
    FKLineDataList.Count - 2) do
  begin
    if (I < FMADataList.Count) and (I + 1 < FMADataList.Count) then
    begin
      X1 := IndexToX(I);
      X2 := IndexToX(I + 1);

      // 检查X坐标是否在线段范围内
      if (X >= Min(X1, X2) - CLICK_TOLERANCE) and
        (X <= Max(X1, X2) + CLICK_TOLERANCE) then
      begin
        // 检查MA5线
        Y1 := PriceToY(FMADataList[I].MA5);
        Y2 := PriceToY(FMADataList[I + 1].MA5);
        Distance := Abs((Y2 - Y1) * X - (X2 - X1) * Y + X2 * Y1 - Y2 * X1) /
          Sqrt(Sqr(Y2 - Y1) + Sqr(X2 - X1));

        if Distance <= CLICK_TOLERANCE then
        begin
          Result := true;
          MAType := 1; // MA5
          Index := I;
          Exit;
        end;

        // 检查MA10线
        Y1 := PriceToY(FMADataList[I].MA10);
        Y2 := PriceToY(FMADataList[I + 1].MA10);
        Distance := Abs((Y2 - Y1) * X - (X2 - X1) * Y + X2 * Y1 - Y2 * X1) /
          Sqrt(Sqr(Y2 - Y1) + Sqr(X2 - X1));

        if Distance <= CLICK_TOLERANCE then
        begin
          Result := true;
          MAType := 2; // MA10
          Index := I;
          Exit;
        end;
      end;
    end;
  end;
end;

procedure TKLineChart.AddAnchorPoint(Index: Integer; MAType: Integer);
var
  AnchorPoint: TAnchorPoint;
  I, StartIdx, EndIdx: Integer;
begin
  if (Index < 0) or (Index >= FKLineDataList.Count) or
    (Index >= FMADataList.Count) then
    Exit;

  // 清除现有锚点
  ClearAnchorPoints;

  // 计算锚点范围：从点击位置开始，向左右两边每间隔5个时间段打一个锚点
  StartIdx := 0;
  EndIdx := Min(FKLineDataList.Count - 1, FMADataList.Count - 1);

  // 先在点击位置添加锚点
  AnchorPoint.Index := Index;
  AnchorPoint.DateTime := FKLineDataList[Index].DateTime;
  AnchorPoint.AnchorType := MAType;

  if MAType = 1 then
    AnchorPoint.Price := FMADataList[Index].MA5
  else
    AnchorPoint.Price := FMADataList[Index].MA10;

  FAnchorPoints.Add(AnchorPoint);

  // 向右添加锚点
  I := Index + 5;
  while I <= EndIdx do
  begin
    AnchorPoint.Index := I;
    AnchorPoint.DateTime := FKLineDataList[I].DateTime;
    AnchorPoint.AnchorType := MAType;

    if MAType = 1 then
      AnchorPoint.Price := FMADataList[I].MA5
    else
      AnchorPoint.Price := FMADataList[I].MA10;

    FAnchorPoints.Add(AnchorPoint);

    // 间隔5个时间段
    I := I + 5;
  end;

  // 向左添加锚点
  I := Index - 5;
  while I >= StartIdx do
  begin
    AnchorPoint.Index := I;
    AnchorPoint.DateTime := FKLineDataList[I].DateTime;
    AnchorPoint.AnchorType := MAType;

    if MAType = 1 then
      AnchorPoint.Price := FMADataList[I].MA5
    else
      AnchorPoint.Price := FMADataList[I].MA10;

    FAnchorPoints.Add(AnchorPoint);

    // 间隔5个时间段
    I := I - 5;
  end;
end;

procedure TKLineChart.ClearAnchorPoints;
begin
  FAnchorPoints.Clear;
end;

procedure TKLineChart.DrawAnchorPoints;
var
  I: Integer;
  AnchorPoint: TAnchorPoint;
  X, Y: Integer;
const
  ANCHOR_SIZE = 6;
begin
  if FAnchorPoints.Count = 0 then
    Exit;

  for I := 0 to FAnchorPoints.Count - 1 do
  begin
    AnchorPoint := FAnchorPoints[I];

    // 只绘制可见范围内的锚点
    if (AnchorPoint.Index >= FStartIndex) and
      (AnchorPoint.Index < FStartIndex + FVisibleCount) then
    begin
      X := IndexToX(AnchorPoint.Index);
      Y := PriceToY(AnchorPoint.Price);

      // 绘制锚点圆圈
      FGPGraphicsBuffer.FillEllipse(FAnchorBrush, X - ANCHOR_SIZE div 2,
        Y - ANCHOR_SIZE div 2, ANCHOR_SIZE, ANCHOR_SIZE);
      FGPGraphicsBuffer.DrawEllipse(FAnchorPen, X - ANCHOR_SIZE div 2,
        Y - ANCHOR_SIZE div 2, ANCHOR_SIZE, ANCHOR_SIZE);
    end;
  end;
end;

end.
