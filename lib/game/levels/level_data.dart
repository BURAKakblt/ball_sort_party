import 'level.dart';

/// The first 10 levels. Layouts are bottom → top.
/// B = Basketbol, F = Futbol, S = Beyzbol, T = Tenis, V = Voleybol.
///
/// `par` = optimal move count (BFS). Difficulty was tuned with
/// `tool/level_metrics.dart`: the win rate of a simulated casual player
/// drops gradually (100 → 14 %) instead of jumping. Level 1 is a 3-move
/// tutorial; tennis arrives in level 4, volleyball in level 6.
/// `test/engine/levels_test.dart` re-verifies solvability and the curve.
const List<Level> kLevels = [
  Level(number: 1, par: 3, layout: ['BBBF', 'FFFB', '']), // tutorial, casual 100 %
  Level(number: 2, par: 8, layout: ['SSFF', 'BSBS', 'FFBB', '', '']), // 100 %
  Level(number: 3, par: 10, layout: ['FSFB', 'FFBS', 'SBBS', '', '']), // 100 %
  Level(number: 4, par: 13, layout: ['SFBT', 'TTFF', 'SBFS', 'TBSB', '', '']), // 94 %
  Level(number: 5, par: 15, layout: ['TFFT', 'SBST', 'TBBF', 'SFBS', '', '']), // 75 %
  Level(number: 6, par: 17, layout: ['VSFT', 'VBBT', 'SBST', 'TFBF', 'SFVV', '', '']), // 69 %
  Level(number: 7, par: 9, layout: ['FFBS', 'BBFS', 'SFBS', '']), // 50 %, first single spare
  Level(number: 8, par: 19, layout: ['FTST', 'SVVB', 'FTVS', 'FVFB', 'BTSB', '', '']), // 48 %
  Level(number: 9, par: 17, layout: ['BSTB', 'SFBT', 'FBTT', 'SFSF', '']), // 24 %
  Level(number: 10, par: 15, layout: ['BFSS', 'STTF', 'FBBB', 'SFTT', '']), // 14 %
];
