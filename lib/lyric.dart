import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:async/async.dart';
import 'package:christian_lyrics/srt_parser.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const _enable_paint_debug = false;

class Lyric extends StatefulWidget {

  Lyric({
    required this.lyric,
    required this.size,
    required this.playing,
    this.lyricLineStyle,
    this.streamPosition,
    this.textAlign = TextAlign.center,
    this.highlight = Colors.red,
    this.onTap,
  }) : assert(lyric.size > 0);

  StreamController<int>? streamPosition;

  final TextStyle? lyricLineStyle;

  final LyricContent lyric;

  final TextAlign textAlign;

  int position = 0;

  final Color highlight;

  final Size size;

  final VoidCallback? onTap;

  final bool playing;

  @override
  State<StatefulWidget> createState() => LyricState();
}

class LyricState extends State<Lyric> with TickerProviderStateMixin {
  LyricPainter? lyricPainter;

  AnimationController? _flingController;

  AnimationController? _lineController;

  AnimationController? _gradientController;

  @override
  void initState() {
    super.initState();
    lyricPainter = LyricPainter(
      widget.lyricLineStyle!,
      widget.lyric,
      textAlign: widget.textAlign,
      highlight: widget.highlight,
    );
    _scrollToCurrentPosition(widget.position);
  }

  @override
  void didUpdateWidget(Lyric oldWidget) {

    //super.didUpdateWidget(oldWidget);

    if (widget.lyric != oldWidget.lyric) {
      lyricPainter = LyricPainter(
        widget.lyricLineStyle!,
        widget.lyric,
        textAlign: widget.textAlign,
        highlight: widget.highlight,
      );
    }

    // if (widget.position != oldWidget.position) {
    //   _scrollToCurrentPosition(widget.position);
    // }

    if (widget.playing != oldWidget.playing) {
      if (!widget.playing) {
        _gradientController?.stop();
      } else {
        _gradientController?.forward();
      }
    }
  }

  /// scroll lyric to current playing position
  void _scrollToCurrentPosition(int milliseconds, {bool animate = true}) {

    if (lyricPainter!.height == -1) {
      WidgetsBinding.instance!.addPostFrameCallback((d) {
//        debugPrint("try to init scroll to position ${widget.position.value},"
//            "but lyricPainter is unavaiable, so scroll(without animate) on next frame $d");
        //TODO maybe cause bad performance
        if (mounted) _scrollToCurrentPosition(milliseconds, animate: false);
      });
      return;
    }

    int line = widget.lyric.findLineByTimeStamp(milliseconds, lyricPainter!.currentLine);

    if (lyricPainter!.currentLine != line && !dragging) {
      double offset = lyricPainter!.computeScrollTo(line);

      if (animate) {
        //print('inject');
        _lineController?.dispose();
        _lineController = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 1000),
        )..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _lineController!.dispose();
              _lineController = null;
            }
          });

        Animation<double> animation =
            Tween<double>(begin: lyricPainter!.offsetScroll, end: lyricPainter!.offsetScroll + offset)
                .chain(CurveTween(curve: Curves.easeInOut))
                .animate(_lineController!);
        animation.addListener(() {
          //print(animation.value);
          //lyricPainter!.offsetScroll = animation.value;
        });
        _lineController!.forward();

        _gradientController?.dispose();
        final entry = widget.lyric[line];
        final startPercent = (milliseconds - entry.position) / entry.duration;
        _gradientController = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: (entry.duration - entry.position).toInt()),
        );
        _gradientController!.addListener(() {
          lyricPainter!.lineGradientPercent = _gradientController!.value;
        });
        if (widget.playing) {
          _gradientController!.forward(from: startPercent);
        } else {
          _gradientController!.value = startPercent;
        }

      } else {
        lyricPainter!.offsetScroll += offset;
      }

    }
    lyricPainter!.currentLine = line;
  }

  bool dragging = false;

  bool _consumeTap = false;

  @override
  void dispose() {
    _flingController?.dispose();
    _flingController = null;
    _lineController?.dispose();
    _lineController = null;
    _gradientController?.dispose();
    _gradientController = null;
    super.dispose();
  }

  Widget? cacheOld;

  @override
  Widget build(BuildContext _) {
    return Container(
      constraints: BoxConstraints(minWidth: 300, minHeight: 120),
      child: GestureDetector(
        onTap: () {
          if (!_consumeTap && widget.onTap != null) {
            widget.onTap!();
          } else {
            _consumeTap = false;
          }
        },
        onTapDown: (details) {
          if (dragging) {
            _consumeTap = true;

            dragging = false;
            _flingController?.dispose();
            _flingController = null;
          }
        },
        onVerticalDragStart: (details) {
          dragging = true;
          _flingController?.dispose();
          _flingController = null;
        },
        onVerticalDragUpdate: (details) {
          //debugPrint("details.primaryDelta : ${details.primaryDelta}");
          lyricPainter!.offsetScroll += details.primaryDelta!;
        },
        onVerticalDragEnd: (details) {
          _flingController = AnimationController.unbounded(
            vsync: this,
            duration: const Duration(milliseconds: 300),
          )
            ..addListener(() {
              double value = _flingController!.value;

              if (value < -lyricPainter!.height || value >= 0) {
                _flingController!.dispose();
                _flingController = null;
                dragging = false;
                value = value.clamp(-lyricPainter!.height, 0.0);
              }
              lyricPainter!.offsetScroll = value;
              lyricPainter!.repaint();
            })
            ..addStatusListener((status) {
              if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
                dragging = false;
                _flingController?.dispose();
                _flingController = null;
              }
            })
            ..animateWith(
                ClampingScrollSimulation(position: lyricPainter!.offsetScroll, velocity: details.primaryVelocity!));
        },
        child: Stack(
          children: [
            RepaintBoundary(child: CustomPaint(
              isComplex: true,
              willChange: true,
              size: widget.size,
              painter: lyricPainter,
            )),

            StreamBuilder(
              stream: widget.streamPosition!.stream,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                final result = snapshot.data ?? 0;
                widget.position = result;
                _scrollToCurrentPosition(widget.position);
                return const Center();
              }
            )

          ],
        ),
      ),
    );
  }
}

class LyricPainter extends ChangeNotifier implements CustomPainter {

  bool preload = false;
  int maxLinePaint = 3;
  double tmpPreDy = 0;

  LyricContent? lyric;
  //List<Subtitle> lyric;
  late List<TextPainter> lyricPainters;

  TextPainter _highlightPainter = TextPainter(textDirection: TextDirection.ltr);

  double _offsetScroll = 0;

  double get offsetScroll => _offsetScroll;

  double _lineGradientPercent = -1;

  double get lineGradientPercent {
    if (_lineGradientPercent == -1) return 1.0;
    return _lineGradientPercent.clamp(0.0, 1.0);
  }

  set lineGradientPercent(double percent) {
    _lineGradientPercent = percent;
    repaint();
  }

  set offsetScroll(double value) {
    if (height == -1) return; // do not change offset when height is not available.
    _offsetScroll = value.clamp(-height, 0.0);
    repaint();
  }

  int currentLine = 0;

  TextAlign textAlign;

  late TextStyle _styleHighlight;

  ///param lyric must not be null
  LyricPainter(TextStyle style, this.lyric, {this.textAlign = TextAlign.center, Color highlight = Colors.red}) {
    assert(lyric != null);
    lyricPainters = [];
    for (int i = 0; i < lyric!.size; i++) {
      var painter = TextPainter(text: TextSpan(style: style, text: lyric![i].line), textAlign: textAlign);
      painter.textDirection = TextDirection.ltr;
//      painter.layout();//layout first, to get the height
      lyricPainters.add(painter);
    }
    _styleHighlight = style.copyWith(color: highlight);
  }

  void repaint() {
    notifyListeners();
  }

  double get height => _height;
  double _height = -1;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {

    //print('re paint');

    _layoutPainterList(size);
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    double dy = offsetScroll + size.height / 2 - lyricPainters[0].height / 2;

    for (int line = 0; line < lyricPainters.length; line++) {
      TextPainter painter = lyricPainters[line];

      if (line == currentLine) {
        _paintCurrentLine(canvas, painter, dy, size);
      } else {
        //if (currentLine + maxLinePaint >= line && currentLine - maxLinePaint <= line) {
        drawLine(canvas, painter, dy, size);
        //}
      }
      dy += painter.height;
    }

    tmpPreDy = dy;
  }

  void _paintCurrentLine(ui.Canvas canvas, TextPainter painter, double dy, ui.Size size) {
    if (dy > size.height || dy < 0 - painter.height) {
      return;
    }

    //for current highlight line, draw background text first
    drawLine(canvas, painter, dy, size);

    _highlightPainter
      ..text = TextSpan(text: (painter.text as TextSpan).text, style: _styleHighlight)
      ..textAlign = textAlign;

    _highlightPainter.layout(); //layout with unbound width

    double lineWidth = _highlightPainter.width;
    double gradientWidth = _highlightPainter.width * lineGradientPercent;
    final double lineHeight = _highlightPainter.height;

    _highlightPainter.layout(maxWidth: size.width);

    final highlightRegion = Path();
    double lineDy = 0;
    while (gradientWidth > 0) {
      double dx = 0;
      if (lineWidth < size.width) {
        dx = (size.width - lineWidth) / 2;
      }
      highlightRegion.addRect(Rect.fromLTWH(0, dy + lineDy, dx + gradientWidth, lineHeight));
      lineWidth -= _highlightPainter.width;
      gradientWidth -= _highlightPainter.width;
      lineDy += lineHeight;
    }

    canvas.save();
    canvas.clipPath(highlightRegion);

    drawLine(canvas, _highlightPainter, dy, size);
    canvas.restore();

    assert(() {
      if (_enable_paint_debug) {
        final painter = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawPath(highlightRegion, painter);
      }
      return true;
    }());
  }

  ///draw a lyric line
  void drawLine(ui.Canvas canvas, TextPainter painter, double dy, ui.Size size) {
    if (dy > size.height || dy < 0 - painter.height) {
      return;
    }
    canvas.save();
    canvas.translate(_calculateAlignOffset(painter, size), dy);

    painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  double _calculateAlignOffset(TextPainter painter, ui.Size size) {
    if (textAlign == TextAlign.center) {
      return (size.width - painter.width) / 2;
    }
    return 0;
  }

  @override
  bool shouldRepaint(LyricPainter oldDelegate) {
    return true;
  }

  void _layoutPainterList(ui.Size size) {
    _height = 0;
    lyricPainters.forEach((p) {
      p.layout(maxWidth: size.width);
      _height += p.height;
    });
  }

  //compute the offset current offset to destination line
  double computeScrollTo(int destination) {
    if (lyricPainters.length <= 0 || this.height == 0) {
      return 0;
    }

    double height = -lyricPainters[0].height / 2;
    for (int i = 0; i < lyricPainters.length; i++) {
      if (i == destination) {
        height += lyricPainters[i].height / 2;
        break;
      }
      height += lyricPainters[i].height;
    }
    return -(height + offsetScroll);
  }

  @override
  bool? hitTest(ui.Offset position) => null;

  @override
  get semanticsBuilder => null;

  @override
  bool shouldRebuildSemantics(LyricPainter oldDelegate) => shouldRepaint((oldDelegate));
}

class LyricContent {
  ///splitter lyric content to line
  static const LineSplitter _SPLITTER = const LineSplitter();

  static const int _default_line_duration = 5 * 1000;

  LyricContent.from(String text) {

    //Parse srt
    List<Subtitle> srtContent = parseSrt(text);

    for (Subtitle item in srtContent) {
      _durations.add(item.range!.begin);
      _lyricEntries.add(LyricEntry(item.rawLines.join("\n"), item.range!.begin, item.range!.end));
    }
  }

  List<int> _durations = [];
  List<LyricEntry> _lyricEntries = [];

  int get size => _durations.length;

  LyricEntry operator [](int index) {
    return _lyricEntries[index];
  }

  int _getTimeStamp(int index) {
    return _durations[index];
  }

  LyricEntry? getLineByTimeStamp(final int timeStamp, final int anchorLine) {
    if (size <= 0) {
      return null;
    }
    final line = findLineByTimeStamp(timeStamp, anchorLine);
    return this[line];
  }

  int findLineByTimeStamp(final int timeStamp, final int anchorLine) {
    int position = anchorLine;
    if (position < 0 || position > size - 1) {
      position = 0;
    }
    if (_getTimeStamp(position) > timeStamp) {
      //look forward
      while (_getTimeStamp(position) > timeStamp) {
        position--;
        if (position <= 0) {
          position = 0;
          break;
        }
      }
    } else {
      while (_getTimeStamp(position) < timeStamp) {
        position++;
        if (position <= size - 1 && _getTimeStamp(position) > timeStamp) {
          position--;
          break;
        }
        if (position >= size - 1) {
          position = size - 1;
          break;
        }
      }
    }
    return position;
  }

  @override
  String toString() {
    return 'Lyric{_lyricEntries: $_lyricEntries}';
  }
}

class LyricEntry {
  static RegExp pattern = RegExp(r"\[\d{2}:\d{2}.\d{2,3}]");

  static int _stamp2int(final String stamp) {
    final int indexOfColon = stamp.indexOf(":");
    final int indexOfPoint = stamp.indexOf(".");

    final int minute = int.parse(stamp.substring(1, indexOfColon));
    final int second = int.parse(stamp.substring(indexOfColon + 1, indexOfPoint));
    int millisecond;
    if (stamp.length - indexOfPoint == 2) {
      millisecond = int.parse(stamp.substring(indexOfPoint + 1, stamp.length)) * 10;
    } else {
      millisecond = int.parse(stamp.substring(indexOfPoint + 1, stamp.length - 1));
    }
    return ((((minute * 60) + second) * 1000) + millisecond);
  }

  ///build from a .lrc file line .such as: [11:44.100] what makes your beautiful
  static void inflate(String line, Map<int, String> map) {
    //TODO lyric info
    if (line.startsWith("[ti:")) {
    } else if (line.startsWith("[ar:")) {
    } else if (line.startsWith("[al:")) {
    } else if (line.startsWith("[au:")) {
    } else if (line.startsWith("[by:")) {
    } else {
      var stamps = pattern.allMatches(line);
      var content = line.split(pattern).last;
      stamps.forEach((stamp) {
        int timeStamp = _stamp2int(stamp.group(0)!);
        map[timeStamp] = content;
      });
    }
  }

  LyricEntry(this.line, this.position, this.duration) : this.timeStamp = getTimeStamp(position);

  final String timeStamp;
  final String line;

  final int position;

  ///the duration of this line
  final int duration;

  @override
  String toString() {
    return 'LyricEntry{line: $line, timeStamp: $timeStamp}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricEntry && runtimeType == other.runtimeType && line == other.line && timeStamp == other.timeStamp;

  @override
  int get hashCode => line.hashCode ^ timeStamp.hashCode;
}

String getTimeStamp(int milliseconds) {
  int seconds = (milliseconds / 1000).truncate();
  int minutes = (seconds / 60).truncate();

  String minutesStr = (minutes % 60).toString().padLeft(2, '0');
  String secondsStr = (seconds % 60).toString().padLeft(2, '0');

  return "$minutesStr:$secondsStr";
}

class PlayingLyric {

  CancelableOperation? _lyricLoader;

  String _message = 'Lyric not found';

  LyricContent? _lyricContent;
  List<Subtitle>? _lyricContentSrt;

  ///[lyric]，[lyric]=null，[message]=null
  String get message => _message;

  LyricContent? get lyric => _lyricContent;

  bool get hasLyric => lyric != null && lyric!.size > 0;

  //Music _music;
  void setLyric({String? lyric}) {
    if (lyric != null && lyric.isNotEmpty) {
      _lyricContent = LyricContent.from(lyric);
    } else {
      _lyricContent = null;
    }
    if (_lyricContent?.size == 0) {
      _lyricContent = null;
    }
    if (_lyricContent == null) {
      _message = 'Lyric content empty';
    }
  }
}
