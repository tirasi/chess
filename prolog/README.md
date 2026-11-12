# Track A: Prolog Claim Checker - Hand-off README

## Overview

The Prolog claim checker is the core verification component of the Chess Confidence-Checker. It takes a FEN position, a proposed move, and structured claims about the board, then verifies each claim using formal chess logic.

## Components

### board.pl - Board Representation & Move Application
- FEN parsing: Convert FEN strings to internal board representation
- Board representation: List of `piece(Type, Color, File, Rank)` facts
- Move application: Apply UCI moves to the board
- Move legality: Verify moves don't leave own king in check

### claims.pl - Claim Evaluation
Eight claim predicates:
- `attacks(S, O)` - Piece at S attacks square O
- `defends(S, O)` - Piece at S defends piece at O
- `controls_square(S, O)` - Piece at S controls square O
- `threatens(S, O)` - Piece at S threatens piece at O
- `pins(S, O)` - Piece at S is pinned to king at O
- `forks(S, O)` - Piece at S forks multiple enemy pieces
- `blocks(S, O)` - Piece at S blocks slider attack on O
- `opens_line(S, O)` - Piece at S opens line to O

### checker.pl - Claim Checker CLI
JSON-in/JSON-out command line program:
- Input: Claims JSON (fen, move, claims[])
- Output: Verdict JSON (move_legal, results[])
- Three-valued logic: true | false | unknown (never true for false, never false for true)

### stockfish.pl - Stockfish Wrapper
- Talk to Stockfish over UCI
- Get top moves at fixed depth
- Compute acceptable set (within threshold_cp of best)
- Return Stockfish verdict JSON

## JSON Contract

### Claims Input (stdin)
```json
{
  "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1",
  "move": "e2e4",
  "claims": [
    {"id": "c1", "type": "attacks", "subject": "e4", "object": "d5", "asserted": true},
    {"id": "c2", "type": "defends", "subject": "e4", "object": "e5", "asserted": true}
  ]
}
```

### Checker Verdict (stdout)
```json
{
  "move_legal": true,
  "results": [
    {"id": "c1", "verdict": "true"},
    {"id": "c2", "verdict": "false"}
  ]
}
```

### Stockfish Verdict (stdout)
```json
{
  "move_valid": true,
  "best_moves": ["e2e4", "d2d4"],
  "eval_delta_cp": 15,
  "depth": 18,
  "threshold_cp": 30
}
```

## Three-Valued Logic

The claim checker uses three-valued logic:
- **true**: Claim is provably true
- **false**: Claim is provably false  
- **unknown**: Cannot prove true or false (neither proven true nor proven false)

**Never** treat `unknown` as true or false. This is the core north star of the project - never a confident wrong answer.

## Running the Checker

```bash
# Run the claim checker CLI
echo '{"fen":"...","move":"e2e4","claims":[...]}' | swipl -q -f prolog/checker.pl

# Or run the Stockfish wrapper
swipl -q -f prolog/stockfish.pl -g "stockfish_verdict(FEN, Depth, ThresholdCP, Verdict), ..."
```

## Golden Tests

Run the golden tests:
```bash
swipl -q -f eval/golden_tests.pl -g "run_tests, halt."
```

All golden tests should pass with zero confident-wrong answers.

## Integration with Track B (LLM Agent)

The Python agent (Track B) calls the Prolog checker CLI and Stockfish wrapper as subprocesses. The contract:

1. Python sends claims JSON to checker CLI stdin
2. Checker returns verdict JSON on stdout
3. Python calls Stockfish wrapper for move evaluation
4. Python fuses verdicts into confidence score
5. Router decides: answer (high), verify/re-prompt (medium), escalate (low)

## Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| board.pl | FEN parsing, board representation, move application, move legality |
| claims.pl | 8 claim predicates (attacks, defends, controls_square, threatens, pins, forks, blocks, opens_line) |
| checker.pl | Claim checker CLI - JSON in/out, three-valued verdicts |
| stockfish.pl | Stockfish wrapper - UCI communication, acceptable set computation |

## Success Criteria

- Zero confident-wrong answers on golden set
- Zero confident-wrong on fuzz tests
- Zero confident-wrong on evaluation set
- Checker determinism across repeated runs
- Stockfish wrapper deterministic across repeated runs

## Risks

- LLM won't emit clean JSON → Track B handles with retry + escalation
- Prolog KB too shallow → Log unknowns, expand KB where they cluster
* Stockfish "acceptable" threshold is arbitrary - Report results at multiple thresholds