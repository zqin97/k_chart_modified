import 'dart:async' show StreamSink;

import 'package:flutter/material.dart';
import 'package:k_chart/utils/number_util.dart';

import '../entity/info_window_entity.dart';
import '../entity/k_line_entity.dart';
import '../utils/date_format_util.dart';
import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';
import 'vol_renderer.dart';

class TrendLine {
  final Offset p1;
  final Offset p2;
  final double maxHeight;
  final double scale;

  TrendLine(this.p1, this.p2, this.maxHeight, this.scale);
}

double? trendLineX;

double getTrendLineX() {
  return trendLineX ?? 0;
}

class ChartPainter extends BaseChartPainter {
  final List<TrendLine> lines; //For TrendLine
  final bool isTrendLine; //For TrendLine
  bool isrecordingCord = false; //For TrendLine
  final double selectY; //For TrendLine
  static get maxScrollX => BaseChartPainter.maxScrollX;
  late BaseChartRenderer mMainRenderer;
  BaseChartRenderer? mVolRenderer, mSecondaryRenderer;
  StreamSink<InfoWindowEntity?>? sink;
  Color? upColor, dnColor;
  Color? ma5Color, ma10Color, ma30Color;
  Color? volColor;
  Color? macdColor, difColor, deaColor, jColor;
  int fixedLength;
  List<int> maDayList;
  final ChartColors chartColors;
  late Paint selectPointPaint, selectorBorderPaint, nowPricePaint;
  final ChartStyle chartStyle;
  final bool hideGrid;
  final bool showNowPrice;
  final VerticalTextAlignment verticalTextAlignment;

  ChartPainter(
    this.chartStyle,
    this.chartColors, {
    required this.lines, //For TrendLine
    required this.isTrendLine, //For TrendLine
    required this.selectY, //For TrendLine
    required datas,
    required scaleX,
    required scrollX,
    required isLongPass,
    required selectX,
    required xFrontPadding,
    isOnTap,
    isTapShowInfoDialog,
    required this.verticalTextAlignment,
    mainState,
    volHidden,
    secondaryState,
    this.sink,
    bool isLine = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
  }) : super(chartStyle,
            datas: datas,
            scaleX: scaleX,
            scrollX: scrollX,
            isLongPress: isLongPass,
            isOnTap: isOnTap,
            isTapShowInfoDialog: isTapShowInfoDialog,
            selectX: selectX,
            mainState: mainState,
            volHidden: volHidden,
            secondaryState: secondaryState,
            xFrontPadding: xFrontPadding,
            isLine: isLine) {
    selectPointPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..color = this.chartColors.selectFillColor;
    selectorBorderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = this.chartColors.selectBorderColor;
    nowPricePaint = Paint()
      ..strokeWidth = this.chartStyle.nowPriceLineWidth
      ..isAntiAlias = true;
  }

  @override
  void initChartRenderer() {
    if (datas != null && datas!.isNotEmpty) {
      var t = datas![0];
      fixedLength =
          NumberUtil.getMaxDecimalLength(t.open, t.close, t.high, t.low);
    }
    mMainRenderer = MainRenderer(
      mMainRect,
      mMainMaxValue,
      mMainMinValue,
      mTopPadding,
      mainState,
      isLine,
      fixedLength,
      this.chartStyle,
      this.chartColors,
      this.scaleX,
      verticalTextAlignment,
      maDayList,
    );
    if (mVolRect != null) {
      mVolRenderer = VolRenderer(mVolRect!, mVolMaxValue, mVolMinValue,
          mChildPadding, fixedLength, this.chartStyle, this.chartColors);
    }
    if (mSecondaryRect != null) {
      mSecondaryRenderer = SecondaryRenderer(
          mSecondaryRect!,
          mSecondaryMaxValue,
          mSecondaryMinValue,
          mChildPadding,
          secondaryState,
          fixedLength,
          chartStyle,
          chartColors);
    }
  }

  @override
  void drawBg(Canvas canvas, Size size) {
    Paint mBgPaint = Paint();
    Gradient mBgGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: chartColors.bgColor,
    );
    Rect mainRect =
        Rect.fromLTRB(0, 0, mMainRect.width, mMainRect.height + mTopPadding);
    canvas.drawRect(
        mainRect, mBgPaint..shader = mBgGradient.createShader(mainRect));

    if (mVolRect != null) {
      Rect volRect = Rect.fromLTRB(
          0, mVolRect!.top - mChildPadding, mVolRect!.width, mVolRect!.bottom);
      canvas.drawRect(
          volRect, mBgPaint..shader = mBgGradient.createShader(volRect));
    }

    if (mSecondaryRect != null) {
      Rect secondaryRect = Rect.fromLTRB(0, mSecondaryRect!.top - mChildPadding,
          mSecondaryRect!.width, mSecondaryRect!.bottom);
      canvas.drawRect(secondaryRect,
          mBgPaint..shader = mBgGradient.createShader(secondaryRect));
    }
    Rect dateRect =
        Rect.fromLTRB(0, size.height - mBottomPadding, size.width, size.height);
    canvas.drawRect(
        dateRect, mBgPaint..shader = mBgGradient.createShader(dateRect));
  }

  @override
  void drawGrid(canvas) {
    if (!hideGrid) {
      mMainRenderer.drawGrid(canvas, mGridRows, mGridColumns);
      mVolRenderer?.drawGrid(canvas, mGridRows, mGridColumns);
      mSecondaryRenderer?.drawGrid(canvas, mGridRows, mGridColumns);
    }
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(mTranslateX * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);
    for (int i = mStartIndex; datas != null && i <= mStopIndex; i++) {
      KLineEntity? curPoint = datas?[i];
      if (curPoint == null) continue;
      KLineEntity lastPoint = i == 0 ? curPoint : datas![i - 1];
      double curX = getX(i);
      double lastX = i == 0 ? curX : getX(i - 1);

      mMainRenderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mVolRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mSecondaryRenderer?.drawChart(
          lastPoint, curPoint, lastX, curX, size, canvas);
    }

    if ((isLongPress == true || (isTapShowInfoDialog && isOnTap)) &&
        isTrendLine == false) {
      drawCrossLine(canvas, size);
    }
    if (isTrendLine == true) drawTrendLines(canvas, size);
    canvas.restore();
  }

  @override
  void drawVerticalText(canvas) {
    var textStyle = getTextStyle(this.chartColors.defaultTextColor);
    if (!hideGrid) {
      mMainRenderer.drawVerticalText(canvas, textStyle, mGridRows);
    }
    mVolRenderer?.drawVerticalText(canvas, textStyle, mGridRows);
    mSecondaryRenderer?.drawVerticalText(canvas, textStyle, mGridRows);
  }

  @override
  void drawDate(Canvas canvas, Size size) {
    if (datas == null) return;

    double columnSpace = size.width / mGridColumns;
    double startX = getX(mStartIndex) - mPointWidth / 2;
    double stopX = getX(mStopIndex) + mPointWidth / 2;
    double x = 0.0;
    double y = 0.0;
    for (var i = 0; i <= mGridColumns; ++i) {
      double translateX = xToTranslateX(columnSpace * i);

      if (translateX >= startX && translateX <= stopX) {
        int index = indexOfTranslateX(translateX);

        if (datas?[index] == null) continue;
        TextPainter tp = getTextPainter(getDate(datas![index].time), null);
        y = size.height - (mBottomPadding - tp.height) / 2 - tp.height;
        x = columnSpace * i - tp.width / 2;
        // Prevent date text out of canvas
        if (x < 0) x = 0;
        if (x > size.width - tp.width) x = size.width - tp.width;
        tp.paint(canvas, Offset(x, y));
      }
    }

//    double translateX = xToTranslateX(0);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStartIndex].id));
//      tp.paint(canvas, Offset(0, y));
//    }
//    translateX = xToTranslateX(size.width);
//    if (translateX >= startX && translateX <= stopX) {
//      TextPainter tp = getTextPainter(getDate(datas[mStopIndex].id));
//      tp.paint(canvas, Offset(size.width - tp.width, y));
//    }
  }

  @override
  void drawCrossLineText(Canvas canvas, Size size) {
    var indexX = calculateSelectedX(selectX);
    KLineEntity pointX = getItem(indexX);

    //horizontal line text
    TextPainter tp = getTextPainter(pointX.close, chartColors.crossTextColor);
    double textHeight = tp.height;
    double textWidth = tp.width;

    double paddingScreenSide = 3;
    double paddingNearPeak = 1;
    double paddingXPeak = 6;
    double paddingY = 1.5;
    double verticalDiff = textHeight / 2 + paddingY;
    double peakX;
    bool isLeft = false;
    // decide whether to stick with KlineEntity point or mouse point
    double y = isTrendLine ? selectY : getMainY(pointX.close);

    if (translateXtoX(getX(indexX)) < mWidth / 2) {
      isLeft = false;
      peakX = textWidth + (paddingScreenSide + paddingNearPeak) + paddingXPeak;

      canvas.drawPath(
        Path()
        ..moveTo(peakX, y)
        ..lineTo(peakX - paddingXPeak, y + verticalDiff)
        ..lineTo(0, y + verticalDiff)
        ..lineTo(0, y - verticalDiff)
        ..lineTo(peakX - paddingXPeak, y - verticalDiff)
        ..close(),
        selectorBorderPaint
      );
      tp.paint(canvas, Offset(paddingScreenSide, y - textHeight / 2));
    } else {
      isLeft = true;
      peakX = mWidth - textWidth - (paddingScreenSide + paddingNearPeak) - paddingXPeak;

      canvas.drawPath(
        Path()
        ..moveTo(peakX, y)
        ..lineTo(peakX + paddingXPeak, y + verticalDiff)
        ..lineTo(mWidth, y + verticalDiff)
        ..lineTo(mWidth, y - verticalDiff)
        ..lineTo(peakX + paddingXPeak, y - verticalDiff)
        ..close(),
        selectorBorderPaint
      );
      tp.paint(canvas, Offset(mWidth - tp.width - paddingScreenSide, y - textHeight / 2));
    }

    // date text
    TextPainter dateTp =
        getTextPainter(getDate(pointX.time), chartColors.crossTextColor);
    textWidth = dateTp.width;
    verticalDiff = textHeight / 2;
    peakX = translateXtoX(getX(indexX));
    y = size.height - mBottomPadding;

    if (peakX < textWidth + 2 * paddingScreenSide) {
      peakX = 1 + textWidth / 2 + paddingScreenSide;
    } else if (mWidth - peakX < textWidth + 2 * paddingScreenSide) {
      peakX = mWidth - 1 - textWidth / 2 - paddingScreenSide;
    }
    double baseLine = textHeight / 2;
    canvas.drawRect(
        Rect.fromLTRB(peakX - textWidth / 2 - paddingScreenSide, y, peakX + textWidth / 2 + paddingScreenSide,
            y + baseLine + verticalDiff),
        selectorBorderPaint);

    dateTp.paint(canvas, Offset(peakX - textWidth / 2, y));

    //长按显示这条数据详情
    sink?.add(InfoWindowEntity(pointX, isLeft: isLeft));
  }

  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {
    //长按显示按中的数据
    if (isLongPress || (isTapShowInfoDialog && isOnTap)) {
      var index = calculateSelectedX(selectX);
      data = getItem(index);
    }
    //松开显示最后一条数据
    mMainRenderer.drawText(canvas, data, x);
    mVolRenderer?.drawText(canvas, data, x);
    mSecondaryRenderer?.drawText(canvas, data, x);
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (isLine == true) return;
    //绘制最大值和最小值
    double x = translateXtoX(getX(mMainMinIndex));
    double y = getMainY(mMainLowMinValue);
    if (x < mWidth / 2) {
      //画右边
      TextPainter tp = getTextPainter(
          "── " + mMainLowMinValue.toStringAsFixed(fixedLength),
          chartColors.minMaxColor);
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
          mMainLowMinValue.toStringAsFixed(fixedLength) + " ──",
          chartColors.minMaxColor);
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
    x = translateXtoX(getX(mMainMaxIndex));
    y = getMainY(mMainHighMaxValue);
    if (x < mWidth / 2) {
      //画右边
      TextPainter tp = getTextPainter(
          "── " + mMainHighMaxValue.toStringAsFixed(fixedLength),
          chartColors.minMaxColor);
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
          mMainHighMaxValue.toStringAsFixed(fixedLength) + " ──",
          chartColors.minMaxColor);
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
  }

  @override
  void drawNowPrice(Canvas canvas, KLineEntity point) {
    if (!this.showNowPrice) {
      return;
    }

    if (datas == null) {
      return;
    }

    double y = getMainY(point.close);

    //视图展示区域边界值绘制
    if (y > getMainY(mMainLowMinValue)) {
      y = getMainY(mMainLowMinValue);
    }

    if (y < getMainY(mMainHighMaxValue)) {
      y = getMainY(mMainHighMaxValue);
    }

    nowPricePaint
      ..color = point.open > point.close
          ? this.chartColors.nowPriceDnColor
          : this.chartColors.nowPriceUpColor;
    //先画横线
    double startX = 0;
    final max = -mTranslateX + mDataLen / scaleX;
    final space =
        this.chartStyle.nowPriceLineSpan + this.chartStyle.nowPriceLineLength;
    while (startX < max) {
      canvas.drawLine(
          Offset(startX, y),
          Offset(startX + this.chartStyle.nowPriceLineLength, y),
          nowPricePaint);
      startX += space;
    }
    //再画背景和文本
    TextPainter tp = getTextPainter(
        point.close.toStringAsFixed(fixedLength), this.chartColors.nowPriceTextColor);

    double peakX;
    double paddingRight = 3;
    double paddingLeft = 1;
    double align = y - tp.height / 2;
    double paddingXPeak = 6;
    double paddingY = 1.5;
    double verticalDiff = tp.height / 2 + paddingY;
    switch (verticalTextAlignment) {
      case VerticalTextAlignment.left:
        peakX = 0;
        break;
      case VerticalTextAlignment.right:
        peakX = mWidth - tp.width - (paddingRight + paddingLeft) - paddingXPeak;
        break;
    }
    canvas.drawPath(
        Path()
        ..moveTo(peakX, y)
        ..lineTo(peakX + paddingXPeak, y + verticalDiff)
        ..lineTo(mWidth, y + verticalDiff)
        ..lineTo(mWidth, y - verticalDiff)
        ..lineTo(peakX + paddingXPeak, y - verticalDiff)
        ..close(),
        nowPricePaint
      );
    tp.paint(canvas, Offset(mWidth - tp.width - paddingRight, align));
  }

//For TrendLine
  void drawTrendLines(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    Paint paint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 1
      ..isAntiAlias = true;
    double x = getX(index);
    trendLineX = x;

    double y = selectY;
    // double bottomEnd = size.height + mBottomPadding + mTopPadding + 10 - mMainRect.height;
    //limit trendline not to exceed outside the chart
    // if (mVolRenderer !=null && mSecondaryRenderer == null){
    //   bottomEnd = size.height - mBottomPadding - mChildPadding - mVolRect!.height;
    // } else if (mVolRenderer == null && mSecondaryRenderer == null ) {
    //   bottomEnd = size.height - mBottomPadding;
    // }
    
    // if (selectY > bottomEnd) {
    //   y = bottomEnd;
    // }

    // k线图竖线
    double max = size.height - mBottomPadding;
    drawDashedLine(canvas, x, max, paint, false);

    //Horizontal Line  
    max = -mTranslateX + mDataLen / scaleX;
    drawDashedLine(canvas, y, max, paint, true);

    if (lines.length >= 1) {
      lines.forEach((element) {
        var y1 = -((element.p1.dy - 35) / element.scale) + element.maxHeight;
        var y2 = -((element.p2.dy - 35) / element.scale) + element.maxHeight;
        var a = (trendLineMax! - y1) * trendLineScale! + trendLineContentRec!;
        var b = (trendLineMax! - y2) * trendLineScale! + trendLineContentRec!;
        var p1 = Offset(element.p1.dx, a);
        var p2 = Offset(element.p2.dx, b);
        canvas.drawLine(
            p1,
            element.p2 == Offset(-1, -1) ? Offset(x, y) : p2,
            Paint()
              ..color = Colors.red
              ..strokeWidth = 2);
      });
    }
  }

  ///画交叉线
  void drawCrossLine(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);
    Paint paintY = Paint()
      ..color = this.chartColors.vCrossColor
      ..strokeWidth = this.chartStyle.vCrossWidth
      ..isAntiAlias = true;
    double x = getX(index);
    double y = getMainY(point.close);
    // k线图竖线
    canvas.drawLine(Offset(x, mTopPadding),
        Offset(x, size.height - mBottomPadding), paintY);

    Paint paintX = Paint()
      ..color = this.chartColors.hCrossColor
      ..strokeWidth = this.chartStyle.hCrossWidth
      ..isAntiAlias = true;
    // k线图横线
    canvas.drawLine(Offset(-mTranslateX, y),
        Offset(-mTranslateX + mWidth / scaleX, y), paintX);
    if (scaleX >= 1) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), height: 2.0 * scaleX, width: 2.0),
          paintX);
    } else {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y), height: 2.0, width: 2.0 / scaleX),
          paintX);
    }
  }

  TextPainter getTextPainter(text, color) {
    if (color == null) {
      color = this.chartColors.defaultTextColor;
    }
    TextSpan span = TextSpan(text: "$text", style: getTextStyle(color));
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  //bool value to tell the program draw horizontal or veritcal line
  void drawDashedLine(Canvas canvas, double point, double max, Paint paint, bool line) {
    const int dashLength = 7;
    const int dashSpace = 5;

    double start = 0;
    double end = point;

    if (line) {
      while (start < max) {
        canvas.drawLine(Offset(start, end), Offset(start + dashLength, end), paint);
        start += dashLength + dashSpace;
      }
    } else {
        while (start < max) {
        canvas.drawLine(Offset(end, start), Offset(end, start + dashLength), paint);
        start += dashLength + dashSpace;
      }
    }
  }

  String getDate(int? date) => dateFormat(
      DateTime.fromMillisecondsSinceEpoch(
          date ?? DateTime.now().millisecondsSinceEpoch),
      mFormats);

  double getMainY(double y) => mMainRenderer.getY(y);

  /// 点是否在SecondaryRect中
  bool isInSecondaryRect(Offset point) {
    return mSecondaryRect?.contains(point) ?? false;
  }

  /// 点是否在MainRect中
  bool isInMainRect(Offset point) {
    return mMainRect.contains(point);
  }
}
