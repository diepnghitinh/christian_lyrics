import 'package:christian_lyrics/lyric.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:christian_lyrics/christian_lyrics.dart';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import 'common.dart';

const lyricText = "1\r\n00:00:01,000 --> 00:00:29,950\r\n* * *\r\n\r\n2\r\n00:00:30,000 --> 00:00:33,350\r\nOh holy night!\r\n\r\n3\r\n00:00:33,400 --> 00:00:37,950\r\nThe stars are brightly shining\r\n\r\n4\r\n00:00:38,000 --> 00:00:46,950\r\nIt is the night of our dear savior's birth\r\n\r\n5\r\n00:00:47,000 --> 00:00:54,950\r\nLong lay the world in sin and error, pining\r\n\r\n6\r\n00:00:55,000 --> 00:01:02,950\r\n'Til He appear'd and the soul felt it's worth.\r\n\r\n7\r\n00:01:03,000 --> 00:01:03,950\r\n \r\n\r\n8\r\n00:01:04,000 --> 00:01:11,350\r\nA thrill of hope, the weary world rejoices\r\n\r\n9\r\n00:01:11,400 --> 00:01:19,950\r\nFor yonder breaks a new and glorious morn\r\n\r\n10\r\n00:01:20,000 --> 00:01:33,950\r\nFall on your knees! O hear the angel voices!\r\n\r\n11\r\n00:01:34,000 --> 00:01:34,950\r\n \r\n\r\n12\r\n00:01:35,000 --> 00:01:48,950\r\nO night divine, O night when Christ was born;\r\n\r\n13\r\n00:01:49,000 --> 00:02:06,950\r\nO night divine, O night, O night Divine.\r\n\r\n14\r\n00:02:07,000 --> 00:02:21,950\r\n \r\n\r\n15\r\n00:02:22,000 --> 00:02:30,950\r\nTruly He taught us to love one another;\r\n\r\n16\r\n00:02:31,000 --> 00:02:39,950\r\nHis law is love and His gospel is peace.\r\n\r\n17\r\n00:02:40,000 --> 00:02:41,950\r\nChains shall He break for the slave is our brother;\r\n\r\n18\r\n00:02:42,000 --> 00:02:56,950\r\nAnd in His name all oppression shall cease.\r\n\r\n19\r\n00:02:57,000 --> 00:03:04,950\r\nSweet hymns of joy in grateful chorus raise we,\r\n\r\n20\r\n00:03:05,000 --> 00:03:12,950\r\nLet all within us praise His holy name.\r\n\r\n21\r\n00:03:13,000 --> 00:03:28,950\r\nChrist is the Lord! O praise His Name forever,\r\n\r\n22\r\n00:03:29,000 --> 00:03:42,950\r\nHis power and glory evermore proclaim.\r\n\r\n23\r\n00:03:43,000 --> 00:03:53,000\r\nHis power and glory evermore proclaim.";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {

  final _player = AudioPlayer();
  final christianLyrics = ChristianLyrics();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.black,
    ));
    _init();
    christianLyrics.setLyricContent(lyricText);
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays speech.
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
          print('A stream error occurred: $e');
        });
    // Try to load audio from a source and catch any errors.
    try {
      //print("${(await getApplicationDocumentsDirectory()).path}");

      await _player.setAudioSource(AudioSource.uri(Uri.parse(
          "asset:///assets/OHolyNight_Christmas2016.mp3")));
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from.
      _player.stop();
    }
  }

  /// Collects the data useful for displaying in a seek bar, using a handy
  /// feature of rx_dart to combine the 3 streams of interest into one.
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
              (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Container(child: StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final playing = playerState?.playing ?? false;
                  return christianLyrics.getLyric(context, isPlaying: playing);
                }), color: Colors.brown)),

              // Display play/pause button and volume/speed sliders.
              ControlButtons(_player, christianLyrics),
              // Display seek bar. Using StreamBuilder, this widget rebuilds
              // each time the position, buffered position or duration changes.
              StreamBuilder<PositionData>(
                stream: _positionDataStream,
                builder: (context, snapshot) {
                  final positionData = snapshot.data;

                  if (positionData != null) {
                    christianLyrics.setPositionWithOffset(position: positionData.position.inMilliseconds, duration: positionData.duration.inMilliseconds);
                  }

                  return SeekBar(
                    duration: positionData?.duration ?? Duration.zero,
                    position: positionData?.position ?? Duration.zero,
                    bufferedPosition:
                    positionData?.bufferedPosition ?? Duration.zero,
                    onChangeEnd: (Duration d) {
                      christianLyrics.resetLyric();
                      christianLyrics.setPositionWithOffset(position: d.inMilliseconds, duration: positionData!.duration.inMilliseconds);
                      _player.seek(d);
                    },
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays the play/pause button and volume/speed sliders.
class ControlButtons extends StatelessWidget {
  final AudioPlayer player;
  final ChristianLyrics christianLyrics;

  ControlButtons(this.player, this.christianLyrics);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Opens volume slider dialog
        IconButton(
          icon: Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),

        /// This StreamBuilder rebuilds whenever the player state changes, which
        /// includes the playing/paused state and also the
        /// loading/buffering/ready state. Depending on the state we show the
        /// appropriate button or loading indicator.
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: () {
                  christianLyrics.resetLyric();
                  player.play();
                },
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero),
              );
            }
          },
        ),
        // Opens speed slider dialog
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                value: player.speed,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}