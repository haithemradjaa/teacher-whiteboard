import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class WhiteboardState extends ChangeNotifier {
  List<DrawingPoint> points = [];
  Color selectedColor = Colors.black;
  double strokeWidth = 2.0;

  void addPoint(DrawingPoint point) {
    points.add(point);
    notifyListeners();
  }

  void clearBoard() {
    points.clear();
    notifyListeners();
  }

  void updateColor(Color color) {
    selectedColor = color;
    notifyListeners();
  }

  void updateStrokeWidth(double width) {
    strokeWidth = width;
    notifyListeners();
  }
}

class DrawingPoint {
  Offset offset;
  Paint paint;

  DrawingPoint({required this.offset, required this.paint});
}