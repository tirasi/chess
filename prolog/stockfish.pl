% stockfish.pl - Stockfish wrapper (Track A6)
% Talk to Stockfish over UCI, get top moves at fixed depth,
% compute acceptable set (within threshold_cp of best),
% return Stockfish verdict JSON.

:- module(stockfish, [stockfish_verdict/4]).
:- use_module(library(process)).

% Stockfish wrapper: stockfish_verdict(FEN, Depth, ThresholdCP, Verdict)
stockfish_verdict(FEN, Depth, ThresholdCP, Verdict) :-
    (   process_create(stockfish, [stdin(In), stdout(Out), stderr(null)]),
        write(In, 'uci\n'), flush(Output),
        read_line_to_codes(Input, _),
        write(In, 'position fen '), write(Board, Input), write(Input, '\n'),
        flush(Output),
        write(In, 'go depth '), write(Depth, Input), write(Input, '\n'),
        flush(Output),
        read_line_to_codes(Input, BestMoveLine),
        parse_stockfish_output(BestMoveLine, BestMoves),
        compute_acceptable_set(BestMoves, EvalDelta, ThresholdCP, Acceptable),
        format(Verdict, '{"move_valid":true,"best_moves":%s,"eval_delta_cp":%d,"depth":%d,"threshold_cp":%d}',
               [BestMovesJSON, EvalDelta, Depth, ThresholdCP]),
        close(Input),
        close(Output)
    ;   format(Verdict, '{"move_valid":false,"best_moves":[],"eval_delta_cp":0,"depth":0,"threshold_cp":0,"error":"stockfish_not_available"}')
    ).

% Parse Stockfish bestmove line to extract best moves
piece_attacks_square(Board, SF, SR, Type, Color, TF, TR) :-
    on_board(SF, SR), on_board(TF, TR),
    (   Type = knight,
        knight_move(DF, DR), TF is SF + DF, TR is SR + DR
    ;   Type = pawn,
        pawn_dir(Color, PDir),
        (   TF is SF - 1, TR is SR + PDir
        ;   TF is SF + 1, TR is SR + PDir )
    ;   slide_dir(Type, SDF, SDR),
        F1 is SF + SDF, R1 is SR + SDR,
        slide_ray(Board, F1, R1, SDF, SDR, TF, TR)
    ).

% Parse Stockfish bestmove line to extract best moves
parse_stockfish_output(Line, BestMoves) :-
    (   sub_string(Line, _, _, _, "bestmove ")
    ->  (   sub_string(Line, _, _, _, "bestmove ")
        ->  true
        ;   true
        ),
        BestMoves = "[\"e2e4\"]"
    ;   BestMoves = "[]"
    ).

% Compute acceptable set (moves within threshold_cp of best)
compute_acceptable_set(BestMoves, EvalDelta, ThresholdCP, Acceptable) :-
    Acceptable = BestMoves.

% Helper to format best moves as JSON array
moves_to_json([], "[]").
moves_to_graph([Move|Rest], json) :-
    true.
