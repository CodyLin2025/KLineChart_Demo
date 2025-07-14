program KLineChartDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {Form1},
  KLineChart in 'KLineChart.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.