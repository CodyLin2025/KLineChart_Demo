# Delphi K线图控件

这是一个使用Delphi XE 10.4开发的K线图控件，采用GDI+双缓存绘图技术，提供流畅的图表显示和交互体验。

## 功能特性

### 核心功能
- ✅ **蜡烛图显示** - 标准的OHLC蜡烛图表示
- ✅ **GDI+双缓存绘图** - 确保流畅的绘图性能
- ✅ **移动平均线** - 支持5日和10日移动平均线
- ✅ **价格网格** - 自动计算和显示价格刻度
- ✅ **时间轴** - 显示时间刻度信息

### 交互功能
- ✅ **鼠标滚轮缩放** - 向上滚动放大，向下滚动缩小
- ✅ **鼠标拖动平移** - 左键拖动可以平移图表
- ✅ **悬停信息提示** - 鼠标悬停显示详细的K线数据

### 数据支持
- ✅ **60分钟K线数据** - 内置测试数据生成器
- ✅ **实时数据更新** - 支持动态添加新的K线数据

## 文件结构

```
KLineChart/
├── KLineChartDemo.dpr     # 主项目文件
├── MainForm.pas           # 主窗体单元
├── MainForm.dfm           # 主窗体设计文件
├── KLineChart.pas         # K线图控件核心单元
└── README.md              # 说明文档
```

## 核心类和数据结构

### TKLineData - K线数据结构
TKLineData = record
  DateTime: TDateTime;  // 时间
  Open: Double;         // 开盘价
  High: Double;         // 最高价
  Low: Double;          // 最低价
  Close: Double;        // 收盘价
  Volume: Int64;        // 成交量

### TMAData - 移动平均线数据
TMAData = record
  MA5: Double;          // 5日移动平均线
  MA10: Double;         // 10日移动平均线
end;

### TKLineChart - 主控件类
主要方法：
- `AddKLineData(const AData: TKLineData)` - 添加K线数据
- `ClearData` - 清空所有数据
- `Refresh` - 刷新图表显示

## 使用方法

### 1. 创建控件实例
var
  KLineChart: TKLineChart;
begin
  KLineChart := TKLineChart.Create(Self);
  KLineChart.Parent := Self;
  KLineChart.Align := alClient;
end;

### 2. 添加K线数据
var
  KLineData: TKLineData;
begin
  KLineData.DateTime := Now;
  KLineData.Open := 100.0;
  KLineData.High := 105.0;
  KLineData.Low := 98.0;
  KLineData.Close := 103.0;
  KLineData.Volume := 1000;
  
  KLineChart.AddKLineData(KLineData);
end;

### 3. 刷新显示
KLineChart.Invalidate; // 或者调用 KLineChart.Refresh;

## 交互操作

### 缩放操作
- **放大**: 鼠标滚轮向上滚动
- **缩小**: 鼠标滚轮向下滚动
- **缩放范围**: 0.1x - 5.0x

### 平移操作
- **平移**: 按住鼠标左键拖动
- **边界限制**: 自动限制在数据范围内

### 信息提示
- **显示**: 鼠标悬停在K线上
- **内容**: 时间、开盘价、最高价、最低价、收盘价、MA5、MA10

## 颜色配置

控件使用以下颜色方案：
- **上涨蜡烛**: 绿色空心矩形
- **下跌蜡烛**: 红色实心矩形
- **MA5线**: 黄色
- **MA10线**: 紫色
- **网格线**: 半透明灰色
- **文字**: 白色
- **背景**: 黑色

## 性能特性

### GDI+双缓存
- 使用TGPBitmap作为后台缓冲区
- 所有绘图操作先在缓冲区完成
- 最后一次性复制到屏幕，避免闪烁

### 优化策略
- 只绘制可见范围内的K线
- 智能计算价格范围
- 高效的移动平均线计算

## 编译要求

- **Delphi版本**: XE 10.4 或更高版本
- **依赖单元**: 
  - Winapi.GDIPOBJ
  - Winapi.GDIPAPI
  - System.Generics.Collections

## 运行项目

1. 打开 `KLineChartDemo.dpr` 项目文件
2. 编译并运行项目
3. 程序会自动生成720个小时的测试数据（30天）
4. 使用鼠标滚轮缩放，拖动平移，悬停查看详细信息

## 扩展功能

控件设计为可扩展的架构，可以轻松添加：
- 更多技术指标（MACD、RSI、布林带等）
- 成交量柱状图
- 更多时间周期支持
- 自定义颜色主题
- 数据导入/导出功能

## 技术细节

### 坐标转换
- `PriceToY()` - 价格转换为Y坐标
- `IndexToX()` - 数据索引转换为X坐标
- `XToIndex()` - X坐标转换为数据索引

### 绘图顺序
1. 背景填充
2. 网格绘制
3. K线绘制
4. 移动平均线绘制
5. 价格刻度绘制
6. 时间刻度绘制
7. 悬停提示绘制