// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('game_of_life_components');

#import('dart:html');
#import('dart:math', prefix: 'Math');
#import('package:dart-web-components/lib/js_polyfill/web_components.dart');

/** Functions used to propogate a tick to cells. */
typedef void Ping();

// We've done things this way because we can't have default values for fields
// inside a web component right now (see bug 4957).

/** How big should the (square) board be by default? Measured in cells/side. */
final int DEFAULT_GAME_SIZE = 40;

/**
 * How many pixels long is the side of a cell by default?
 * (Note: must match the CSS!)
 */
final int DEFAULT_CELL_SIZE = 20;

/** How many pixels from the game should the control panel be by default? */
final int DEFAULT_PANEL_OFFSET = 20;

/** How many milliseconds between steps by default? */
final int DEFAULT_STEP_TIME = 100;

/** 
 * Maps tag names to Dart constructors for components in this library.
 * Singleton.
 */
Map<String, WebComponentFactory> get CTOR_MAP {
  if (_CTOR_MAP == null) {
    _CTOR_MAP = {
      'x-cell' : () => new Cell.component(),
      'x-control-panel' : () => new ControlPanel.component(),
      'x-game-of-life' : () => new GameOfLife.component()
    };
  }
  return _CTOR_MAP;
}

Map<String, WebComponentFactory> _CTOR_MAP;

/** 
 * If the importing code uses only the components in this library, 
 * this function will do all necessary component initialization.
 */
void gameOfLifeComponentsSetup() {
  initializeComponents((String name) => CTOR_MAP[name], false);
}

/**
 * A single cell in the Game Of Life. Listens to a GameOfLife parent component
 * to get a clock tick, and interacts on its neighbors on every tick to move the
 * game one step forward.
 */
class Cell implements WebComponent, Hashable {
  Element element;
  Collection<Cell> neighbors;
  ShadowRoot _root;
  GameOfLife game;
  bool aliveThisStep;
  bool aliveNextStep;

  Cell.component();

  get classes => element.classes;
  get id => element.id;
  set id(String id) {
    element.id = id;
  }

  factory Cell() {
    return manager.expandHtml('<div is="x-cell"></div>');
  }

  void created(ShadowRoot root) {
    _root = root;
    element.xtag = this;
    neighbors = <Cell>[];
    element.classes.add('cell');

    // Cells start dead.
    aliveThisStep = false;
  }

  void inserted() { }

  /**
   * Set up event listeners and populate [neighbors] by querying [game] for this
   * cell's neighbors. Event listeners can be done here rather than dealt with
   * in [inserted] and [removed] because cells will always be gc'd if removed
   * from the DOM.
   */
  void bound() {
    element.on.click.add((event) {
      element.classes.toggle('alive');
      aliveThisStep = !aliveThisStep;
    });

    game.on.step.add(step);
    game.on.resolve.add(resolve);

    // find neighbors
    var parsedCoordinates = element.id.substring(1).split('y');
    var x = Math.parseInt(parsedCoordinates[0]);
    var y = Math.parseInt(parsedCoordinates[1]);
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (game.inGrid(x + dx, y + dy) && !(dx == 0 && dy == 0)) {
          var neighbor = game._query('#x${x + dx}y${y + dy}');
          neighbors.add(neighbor);
        }
      }
    }
  }

  
  void attributeChanged(String name, String oldValue, String newValue) { }

  void removed() { }

  /**
   * Each turn of the game is broken into a step and a resolve. On a step, the
   * cell queries its neighbors current states and decides whether or not will
   * be alive or dead next turn.
   */
  void step() {
    var numAlive = neighbors.filter((n) => n.aliveThisStep).length;
    // We could compress this into one line, but it's clearer this way.
    aliveNextStep = false;
    if (aliveThisStep) {
      if (numAlive == 2 || numAlive == 3) {
        aliveNextStep = true;
      }
    } else {
      if (numAlive == 3) {
        aliveNextStep = true;
      }
    }
  }

  /**
   * Each turn of the game is broken in a step and a resolve. On a resolve, the
   * cell uses the information collected in the step phase to update its state
   * and appearance -- black if alive this turn, white if dead this turn.
   */
  void resolve() {
    if (aliveNextStep) {
      element.classes.add('alive');
    } else {
      element.classes.remove('alive');
    }
    aliveThisStep = aliveNextStep;
  }

}

/** 
 * A control panel for the Game of Life. Has start, stop, and step buttons which
 * start the game, stop the game, and move the game one turn forward,
 * respectively.
 */
class ControlPanel implements WebComponent {
  Element element;
  ShadowRoot _root;
  GameOfLife game;

  ControlPanel.component();

  factory ControlPanel() {
    return manager.expandHtml('<div is="x-control-panel"></div>');
  }

  void set id(String id) {
    element.id = id;
  }

  void created(ShadowRoot root) {
    _root = root;
    element.xtag = this;
  }

  void inserted() { }

  /** 
   * Sets up event listeners for the buttons. This must be done here rather than
   * in [inserted] because the events must propogate up to [game].
   */
  void bound() { 
    _root.query('#start').on.click.add((e) => game.run());
    _root.query('#stop').on.click.add((e) => game.stop());
    _root.query('#step').on.click.add((e) => game.step());
  }

  void attributeChanged(String name, String oldValue, String newValue) { }

  void removed() { }
}

/** 
 * A Game of Life component, containing an interactive implementation of
 * Conway's Game of Life.
 */
class GameOfLife implements WebComponent {

  // Implementation Notes: The game consists of a control panel and a board
  // composed of cells. Each cell is a web component, and the control panel is a
  // web component. The top-level widget populates the board with cells and
  // provides a clock tick to which the cells listen. It exposes API to stop and
  // start that tick, which the control panel binds to its buttons. Aside
  // from the tick, no state is maintained in the top level widget -- each cell
  // maintains its own state and talks to its neighbors to move the game
  // forward.

  // TODO(samhop): implement wraparound on the board.
  Element element;
  ShadowRoot _root;
  GameOfLifeEvents on;
  Timer timer;
  int lastRefresh;
  bool _stop;
  StyleElement computedStyles;

  // These cannot be initialized here right now -- see bug 4957.

  /** How big should the (square) board be? Measured in cells/side. */
  int GAME_SIZE;

  /** How many pixels long is the side of a cell? (Note: must match the CSS!) */
  int CELL_SIZE;

  /** How many pixels from the game should the control panel be? */
  int PANEL_OFFSET;

  /** How many milliseconds between steps? */
  int _stepTime;

  Map<String, WebComponent> childTable;

  void set stepTime(int time) {
    _stepTime = time;
  }

  GameOfLife.component();

  factory GameOfLife() {
    return manager.expandHtml('<div is="x-game-of-life"></div>');
  }

  /** On creation, initialize fields and then populate the game. */
  void created(ShadowRoot root) {
    _root = root;
    element.xtag = this;
    on = new GameOfLifeEvents();
    lastRefresh = 0;
    childTable = new Map<String, WebComponent>();
    
    // At present we must do this initialization here -- see bug 4957.
    GAME_SIZE = DEFAULT_GAME_SIZE;
    CELL_SIZE = DEFAULT_CELL_SIZE;
    PANEL_OFFSET = DEFAULT_PANEL_OFFSET;
    _stepTime = DEFAULT_STEP_TIME;

    _populate();
  }

  void inserted() { }

  void attributeChanged(String name, String oldValue, String newValue) { }

  void removed() { }

  /** 
   * Returns the results of querying on [selector] beneath [_root]. Needed by
   * Cells to determine their neighbors.
   */
  _query(String selector) {
    var result = _root.query(selector);
    var lookup = childTable[result.id];
    if (lookup != null) {
      return lookup;
    }
    return result;
  }

  _queryAll(String selector) {
    var result = _root.queryAll(selector);
    return result.map((elt) {
      var lookup = childTable[elt.id];
      if (lookup != null) {
        return lookup;
      }
      return elt;
    });
  }

  _addShadowChild(child) {
    if (child is WebComponent) {
      _root.nodes.add(child.element);
      // HACK relies on all elemenents having distinct ids, since DOM nodes
      // aren't hashable
      childTable[child.element.id] = child;
    } else {
      _root.nodes.add(child);
    }
  }

  /** Stop ticking. */
  void stop() {
    _stop = true;
  }

  /** 
   * Tick once, if it has been at least _stepTime milliseconds since the last
   * tick. Then, if we haven't been told to stop, call set up a
   * requestAnimationFrame callback to tick again.
   */
  void _increment(int time) {
    if (new Date.now().millisecondsSinceEpoch - lastRefresh >= _stepTime) {
      on.step.forEach((f) => f());
      on.resolve.forEach((f) => f());
      lastRefresh = new Date.now().millisecondsSinceEpoch;
    }
    if (!_stop) {
       window.requestAnimationFrame(_increment);
    }
  }

  /** Start the game. */
  void run() {
    _stop = false;
    window.requestAnimationFrame(_increment);
  }

  /** 
   * Move the game one step forward. If the game was running, stop the game
   * beforehand.
   */
  void step() {
    _stop = true;
    _increment(null);
  }

  /** 
   * Fill the game board with cells, position them appropriately, position the 
   * control panel, and bind all subcomponents.
   */
  void _populate() {
    // set up position styles
    computedStyles = new StyleElement();
    _addShadowChild(computedStyles);
    var computedStylesBuffer = new StringBuffer(); 
    _forEachCell((i, j) =>  _addPositionId(computedStylesBuffer, i, j));

    // position the control panel
    var panelStyle = 
        '''
        #panel {
          top: ${CELL_SIZE * GAME_SIZE + PANEL_OFFSET}px;
          left: ${PANEL_OFFSET}px;
        }
        ''';
    computedStylesBuffer.add('${computedStyles.innerHTML}\n$panelStyle');

    computedStyles.innerHTML = computedStylesBuffer.toString();

    // HACK HACK HACK -- do this before adding cells so that perf numbers don't
    // change too much
    var controlPanelTmp = manager[_query('div[is="x-control-panel"]')];
    childTable[controlPanelTmp.element.id] = controlPanelTmp;

    // add cells
    _forEachCell((i, j) {
      var cell = new Cell();
      cell.game = this;
      cell.id = _generatePositionString(i, j);
      _addShadowChild(cell);
    });

    // bind the control panel
    var controlPanel = _query('div[is="x-control-panel"]');
    controlPanel.game = this;
    controlPanel.bound();

    // TODO(samhop): fix webcomponents.dart so that attributes are preserved.
    _query('div').id = 'panel';

    // TODO(samhop) fix webcomponents.dart so we don't have to do this
    _queryAll('.cell').forEach((cell) => cell.bound());
  }

  /** 
   * Calls f exactly once on all pairs (i, j) for ints i, j between 0 and
   * [GAME_SIZE] - 1, inclusive.
   */
  void _forEachCell(f) {
    for (var i = 0; i < GAME_SIZE; i++) {
      for (var j = 0; j < GAME_SIZE; j++) {
        f(i, j);
      }
    }
  }
  
  /**
   * Appends correct cell positioning information for cell ([i], [j]) to [curr].
   */
  String _addPositionId(StringBuffer curr, int i, int j) =>
      curr.add(
      '''
      #${_generatePositionString(i, j)} {
        left: ${CELL_SIZE * i}px;
        top: ${CELL_SIZE * j}px;
      }
      ''');

  /** Returns the cell id corresponding to ([i], [j]). */
  String _generatePositionString(int i, int j) => 'x${i}y${j}';

  /** 
   * Is the coordinate ([x],[y]) in the game grid, given the current
   * [GAME_SIZE]?
   */
  bool inGrid(x, y) =>
    (x >=0 && y >=0 && x < GAME_SIZE && y < GAME_SIZE);

  /** 
   * Set cell ([i],[j])'s aliveness to [alive]. Throws an
   * IllegalArgumentException if ([i],[j]) is not a valid cell (i.e. if it is
   * outside of the grid).
   */
  void setAliveness(int i, int j, bool alive) {
    _validateGridPosition(i, j);
    _query('#${_generatePositionString(i, j)}').aliveThisStep = alive;
  }

  /**
   * Is cell ([i], [j]) currently alive? Throws an IllegalArgumentException if
   * ([i], [j]) is not a valid cell (i.e. it is outside the grid).
   */
  bool isAlive(int i, int j) {
    _validateGridPosition(i, j);
    return _query('#${_generatePositionString(i,j)}').aliveThisStep;
  }

  /** Throw an IllegalArgumentException if ([i], [j]) is not a valid cell. */
  void _validateGridPosition(int i, int j) {
    if (i < 0 || j < 0 || !inGrid(i,j)) {
      throw new IllegalArgumentException('(${i}, ${j}) is a bad coordinate');
    }
    assert(inGrid(i,j) && i >= 0 && j >= 0);
  }
}

/** Events container for a GameOfLife. */
class GameOfLifeEvents implements Events {
  List<Ping> _step_list;
  List<Ping> _resolve_list;

  GameOfLifeEvents() 
      : _step_list = <Ping>[],
        _resolve_list = <Ping>[];

  List<Ping> get step => _step_list;
  List<Ping> get resolve => _resolve_list;
}
