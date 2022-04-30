
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'lyric.dart';

class ChristianLyrics {

  StreamController<int> positionWithOffsetController = StreamController<int>.broadcast();
  int lastPositionUpdateTime = 0;
  int positionWithOffset = 0;
  int lastPositionWithOffset = 0;
  Widget? cacheLyricWidget;

  PlayingLyric? playingLyric = PlayingLyric();

  ChristianLyrics() {
    resetLyric();
  }

  void resetLyric() {
    lastPositionUpdateTime = DateTime.now().millisecondsSinceEpoch;
    lastPositionWithOffset = positionWithOffset;
    //print("a: ${lastPositionUpdateTime} - ${lastPositionWithOffset}");
  }

  void setLyricContent(String lyricContent) {
    positionWithOffset = 0;
    this.playingLyric!.setLyric(lyric: lyricContent);
  }

  void setPositionWithOffset({int position=0, int duration=1}) {
    positionWithOffset = position;
    positionWithOffsetController.add(positionWithOffset);
  }

  Widget getLyric(BuildContext context, {bool isPlaying = false}) {

    TextStyle style = Theme.of(context).textTheme.bodyText1!.copyWith(height: 1.5, fontSize: 20, color: Colors.white);

    if (this.playingLyric!.hasLyric) {
      return LayoutBuilder(builder: (context, constraints) {
        final normalStyle = style.copyWith(color: style.color!.withOpacity(0.7));
        return ShaderMask(
          shaderCallback: (rect) {
            return ui.Gradient.linear(Offset(rect.width / 2, 0), Offset(rect.width / 2, constraints.maxHeight), [
              const Color(0x00FFFFFF),
              style.color!,
              style.color!,
              const Color(0x00FFFFFF),
            ], [
              0.0,
              0.15,
              0.85,
              1
            ]);
          },
          // child: Padding(
          //     padding: EdgeInsets.symmetric(horizontal: 20),
          //     child: StreamBuilder(
          //         stream: positionWithOffsetController.stream,
          //         builder: (BuildContext context, AsyncSnapshot snapshot) {
          //           final result = snapshot.data ?? 0;
          //
          //           //print('position: ${result} - ${positionWithOffset} - isPlaying: ${isPlaying}');
          //
          //           return Lyric(
          //             lyric: playingLyric!.lyric!,
          //             lyricLineStyle: normalStyle,
          //             highlight: style.color!,
          //             position: result,
          //             streamPosition: positionWithOffsetController,
          //             // cacheLyricWidget: (Widget wg) {
          //             //   cacheLyricWidget ??= wg;
          //             //   return cacheLyricWidget;
          //             // },
          //             onTap: () {
          //             },
          //             size: Size(constraints.maxWidth, constraints.maxHeight == double.infinity ? 0 : constraints.maxHeight),
          //             playing: isPlaying,
          //           );
          //         }
          //     )
          // ),
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Lyric(
                lyric: playingLyric!.lyric!,
                lyricLineStyle: normalStyle,
                highlight: style.color!,
                streamPosition: positionWithOffsetController,
                onTap: () {
                },
                size: Size(constraints.maxWidth, constraints.maxHeight == double.infinity ? 0 : constraints.maxHeight),
                playing: isPlaying,
              )
          ),
        );
      });
    } else {
      return Container(
        child: Center(
          child: Text(playingLyric!.message, style: style),
        ),
      );
    }

  }

}
