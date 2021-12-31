import 'package:csslib/parser.dart';
import 'package:meta/meta.dart';
import 'dart:convert' show LineSplitter;

import 'color_map.dart';

/// formatting (partial compliance) : https://en.wikipedia.org/wiki/SubRip#Formatting
class Range {
  Range(this.begin, this.end);

  int begin;
  int end;

  Duration get duration => Duration(milliseconds: end - begin);
}

class HtmlCode {
  bool i = false;
  bool u = false;
  bool b = false;
  Color fontColor = Color.black;
}

class Coordinates {
  Coordinates({this.x, this.y});

  final int? x;
  final int? y;
}

class Subtitle {
  int? id;
  Range? range;
  List<Line> parsedLines = [];
  List<String> rawLines = [];
}

class Line {
  Line(this.rawLine);

  final String rawLine;
  Coordinates? coordinates;

  // TODO(Arman):Either a whole line has code or subLines have or none
  List<SubLine> subLines = [];
}

class SubLine {
  SubLine({this.rawString});

  HtmlCode htmlCode = HtmlCode();
  String? rawString;
}

@visibleForTesting
void parseHtml(Subtitle subtitle) {
  //https://regex101.com/r/LtkFNE/4
  final RegExp detectAll = RegExp(
      r'((<(b|i|u|(font color="((#([0-9a-fA-F]+))|((rgb|rgba)\(((\d{1,3}),(\d{1,3}),(\d{1,3})|(\d{1,3}),(\d{1,3}),(\d{1,3}),(0?\.[1-9]{1,2}|1))\))|([a-z]+))"))>)+)([^<|>|\/]+)((<\/(b|i|u|font)>)+)+|([^<|>|\/]+)');

  final RegExp detectFont = RegExp(r'(<font color=")');
  final RegExp detectI = RegExp(r'(<i>)');
  final RegExp detectB = RegExp(r'(<b>)');
  final RegExp detectU = RegExp(r'(<u>)');

  for (String line in subtitle.rawLines) {
    int index = subtitle.rawLines.indexOf(line);
    Iterable<Match> allMatches = detectAll.allMatches(line);

    for (Match match in allMatches) {
      String? firstMatch = match.group(1);
      // not coded text
      if (match.group(23) != null) {
        subtitle.parsedLines[index].subLines
            .add(SubLine(rawString: match.group(23)));
        continue;
      }
      //Html-coded text
      else {
        SubLine subLineWithCode = SubLine();

        if (detectI.hasMatch(firstMatch!)) {
          subLineWithCode.htmlCode.i = true;
        }

        if (detectB.hasMatch(firstMatch)) {
          subLineWithCode.htmlCode.b = true;
        }
        if (detectU.hasMatch(firstMatch)) {
          subLineWithCode.htmlCode.u = true;
        }
        //font color
        if (detectFont.hasMatch(firstMatch)) {
          //hexColor
          if (match.group(7) != null) {
            subLineWithCode.htmlCode.fontColor = Color.hex(match.group(7)!);
          }
          //rgb or rgba
          if (match.group(8) != null) {
            if (match.group(9) == 'rgb') {
              subLineWithCode.htmlCode.fontColor = Color.createRgba(
                  int.parse(match.group(11)!),
                  int.parse(match.group(12)!),
                  int.parse(match.group(13)!));
            }
            if (match.group(9) == 'rgba') {
              subLineWithCode.htmlCode.fontColor = Color.createRgba(
                  int.parse(match.group(14)!),
                  int.parse(match.group(15)!),
                  int.parse(match.group(16)!),
                  num.parse(match.group(17)!));
            }
          }

          // if color word names
          if (match.group(18) != null) {
            subLineWithCode.htmlCode.fontColor = colorMap.entries
                .firstWhere((MapEntry entry) => entry.key == match.group(18))
                .value;
          }
        }
        subLineWithCode.rawString = match.group(19);

        subtitle.parsedLines[index].subLines.add(subLineWithCode);
      }
    }
  }
}

@visibleForTesting
void parseCoordinates(Subtitle subtitle, String chunk1) {
  final RegExp detectCoordination = RegExp(r'((X|Y)(\d)):(\d\d\d)');

  final Iterable<Match> result = detectCoordination.allMatches(chunk1);

  if (result.length != 0) {
    List listOfXs =
        result.where((Match match) => match.group(2) == 'X').toList();

    //divide by 2 and create a Coordination of each X:Y group
    for (Match item in listOfXs) {
      int number = int.parse(item.group(3)!);
      Match matchingY = result.firstWhere((Match matchY) {
        return (matchY.group(2) == 'Y' && int.parse(matchY.group(3)!) == number);
      });

      Line parsedLine = Line(subtitle.rawLines[listOfXs.indexOf(item)]);
      parsedLine.coordinates = Coordinates(
          x: int.parse(item.group(4)!), y: int.parse(matchingY.group(4)!));

      subtitle.parsedLines.add(parsedLine);
    }
  } else {
    for (String line in subtitle.rawLines) {
      Line parsedLine = Line(line);
      subtitle.parsedLines.add(parsedLine);
    }
  }
}

@visibleForTesting
Range? parseBeginEnd(String line) {
  final RegExp pattern = RegExp(
      r'(\d\d):(\d\d):(\d\d),(\d\d\d) --> (\d\d):(\d\d):(\d\d),(\d\d\d)');
  final Match match = pattern.firstMatch(line)!;

  if (match == null) {
    return null;
  } else if (int.parse(match.group(1)!) > 23 ||
      int.parse(match.group(2)!) > 59 ||
      int.parse(match.group(3)!) > 59 ||
      int.parse(match.group(4)!) > 999 ||
      int.parse(match.group(5)!) > 23 ||
      int.parse(match.group(6)!) > 59 ||
      int.parse(match.group(7)!) > 59 ||
      int.parse(match.group(8)!) > 999) {
    throw RangeError(
        'time components are out of range. Please modify the .srt file.');
  } else {
    final int begin = timeStampToMillis(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!));

    final int end = timeStampToMillis(
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
        int.parse(match.group(7)!),
        int.parse(match.group(8)!));

    return Range(begin, end);
  }
}

@visibleForTesting
int timeStampToMillis(int hour, int minute, int sec, int ms) {
  if (hour <= 23 &&
      hour >= 0 &&
      minute <= 59 &&
      minute >= 0 &&
      sec <= 59 &&
      sec >= 0 &&
      ms <= 999 &&
      ms >= 0) {
    int result = ms;
    result += sec * 1000;
    result += minute * 60 * 1000;
    result += hour * 60 * 60 * 1000;
    return result;
  } else {
    throw RangeError('sth. is outa range');
  }
}

@visibleForTesting
List<String> splitIntoLines(String data) {
  return LineSplitter().convert(data);
}

//splits
@visibleForTesting
List<List<String>> splitByEmptyLine(List<String> lines) {
  final List<List<String>> result = [];
  List<String> chunk = <String>[];

  for (String line in lines) {
    if (line.isEmpty) {
      result.add(chunk);
      chunk = [];
    } else {
      chunk.add(line);
    }
  }
  if (chunk.isNotEmpty) {
    result.add(chunk);
  }

  return result;
}

List<Subtitle> parseSrt(String srt) {
  final List<Subtitle> result = [];

  final List<String> split = splitIntoLines(srt);
  final List<List<String>> splitChunk = splitByEmptyLine(split);

  for (List<String> chunk in splitChunk) {
    final Subtitle subtitle = Subtitle();
    subtitle.id = int.parse(chunk[0]);
    subtitle.range = parseBeginEnd(chunk[1]);
    subtitle.rawLines = chunk.sublist(2);
    parseCoordinates(subtitle, chunk[1]);
    parseHtml(subtitle);
    result.add(subtitle);
  }

  return result;
}
