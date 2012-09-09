Conway's Game of Life
=====================

This package contains a reusable Game of Life widget built using Dart web
components. Here's a rundown of what's here:

  `components/`  contains the web components used to build the game
  `test/` contains unit tests
  `index.html`, `game_of_life.dart` are a sample app consisting of exactly one
      Game of Life widget and nothing else.

Compiling and Running
---------------------

To use these components, or to compile the sample app, you must have the
experimental version of dart2js with no-wrapper web components support. You can
get it at `https://github.com/samhopkins/bleeding_edge`. Then to compile the
sample, run
  
  `dart2js game_of_life.dart -ogame_of_life.js`

and open `index.html` in a browser.

To use the Game of Life component in your app, import
`components/components.dart`.

Running the Tests
-----------------

We cannot presently use the usual test infrastructure in the repo, since it does
not play well with pub right now. To run the tests, first compile them with

  `dart2js tests/game_of_life_tests.dart -o tests/game_of_life_tests.js`.

Then open `tests/test_page.html` in your browser.
