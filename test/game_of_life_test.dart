// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('game_of_life_tests');

#import('dart:html');
#import('package:unittest/unittest.dart');
#import('package:unittest/html_config.dart');
#import('../components/components.dart');

main() {
  useHtmlConfiguration();
  test('Correct propogation of a glider', () {
    gameOfLifeComponentsSetup();
    var game = new GameOfLife();
    game.stepTime = 0;

    // make a glider
    gliderPattern(game, (i, j) => game.setAliveness(i, j, true), 0, 0);

    // We use 12 because it's a multiple of the period of a glider.
    for(int i = 0; i < 12; i++) {
      game.step();
    }

    // gliders move at c/4
    gliderPattern(game, (i, j) => expect(game.isAlive(i, j)), 3, 3);

  });
}

/** 
 * Takes a [game], x and y offsets [x] and [y], and a function [f] of two
 * integer inputs and calls [f] on all the squares of a glider pattern with
 * upper left corner at ([x], [y]). Does not validate [x], [y] -- behavior on
 * invalid [x] and [y] is undefined.
 */
void gliderPattern(GameOfLife game, Function f, int x, int y) {
  f(x, y);
  f(x + 1, y + 1);
  f(x + 2, y);
  f(x + 1, y + 2);
  f(x + 2, y + 1);
}

void _componentsSetup() {
  initializeComponents((String name) => CTOR_MAP[name], true);
}
