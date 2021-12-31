# christian_lyrics

Flutter plugin that allows you build lyrics srt type of song.

## Getting Started

# srt file format
```
1
00:05:00,400 --> 00:05:15,300
This is an example of
a subtitle.

2
00:05:16,400 --> 00:05:25,300
This is an example of
a subtitle - 2nd subtitle.
```

# How to use
```
final christianLyrics = ChristianLyrics();
christianLyrics.setLyricContent(lyricText);

//Build widget
christianLyrics.getLyric(context, isPlaying: true);
```

# Demo
![Demo](screenshot_01.png 300)