unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, KLineChart;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FKLineChart: TKLineChart;
    procedure LoadTestData;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  // 创建K线图控件
  FKLineChart := TKLineChart.Create(Self);
  FKLineChart.Parent := Self;
  FKLineChart.Align := alClient;
  // FKLineChart.Color := clBlack;

  // 加载测试数据
  LoadTestData;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FKLineChart.Free;
end;

procedure TForm1.LoadTestData;
var
  I: Integer;
  KLineData: TKLineData;
  BasePrice: Double;
  DateTime: TDateTime;
begin
  // 生成60分钟K线测试数据
  BasePrice := 100.0;
  DateTime := Now - 30; // 30天前开始

  for I := 0 to 719 do // 30天 * 24小时 = 720个小时数据
  begin
    KLineData.DateTime := DateTime + (I / 24.0);

    // 模拟价格波动
    KLineData.Open := BasePrice + Random(10) - 4;
    KLineData.High := KLineData.Open + Random(5);
    KLineData.Low := KLineData.Open - Random(5);
    KLineData.Close := KLineData.Low +
      Random(Trunc(KLineData.High - KLineData.Low) + 1);
    KLineData.Volume := 1000 + Random(5000);

    BasePrice := KLineData.Close; // 下一根K线以当前收盘价为基准

    FKLineChart.AddKLineData(KLineData);
  end;

  FKLineChart.Invalidate;
end;

end.
