import 'level.dart';

/// Handcrafted test levels. Layouts are bottom → top.
/// B = Basketbol, F = Futbol, S = Beyzbol, T = Tenis, V = Voleybol.
/// `par` is the optimal move count found by `tool/level_tool.dart` (BFS);
/// `test/engine/levels_test.dart` re-verifies every level is solvable.
const List<Level> kLevels = [
  Level(number: 1, par: 5, layout: ['FBFF', 'BBBF', '']),
  Level(number: 2, par: 8, layout: ['SSBF', 'SBBB', 'FFFS', '', '']),
  Level(number: 3, par: 10, layout: ['SSBF', 'SFFS', 'BFBB', '', '']),
  Level(number: 4, par: 10, layout: ['FBFS', 'SBBS', 'FFSB', '']),
  Level(number: 5, par: 12, layout: ['SBFB', 'FSFS', 'SFBB', '']),
  Level(number: 6, par: 14, layout: ['TBTS', 'BFBS', 'FTTS', 'FFSB', '', '']),
  Level(number: 7, par: 15, layout: ['TBSF', 'TFST', 'SFSB', 'BFTB', '', '']),
  Level(number: 8, par: 17, layout: ['SFSF', 'BTBF', 'TSTT', 'SBBF', '']),
  Level(
    number: 9,
    par: 20,
    layout: ['BSTS', 'VFBV', 'BTFV', 'STVS', 'BTFF', '', ''],
  ),
  Level(number: 10, par: 23, layout: ['FBVB', 'FTSB', 'TVFT', 'SFTV', 'VBSS', '']),
];
