% checker.pl - Claim checker CLI.
% JSON in on stdin (claims contract), JSON out on stdout (verdict contract).
% Three-valued verdicts: true | false | unknown.

:- module(checker, [main/0]).

:- use_module(board).
:- use_module(claims).
:- use_module(library(http/json)).
:- use_module(library(lists)).

main :-
    (   json_read(current_input, Input)
    ->  (   get_field(Input, fen, FEN),
            get_field(Input, move, Move),
            get_field(Input, claims, Claims)
        ->  run(FEN, Move, Claims)
        ;   write_error("missing fen/move/claims")
        )
    ;   write_error("unparseable input")
    ),
    halt.

run(FEN, Move, Claims) :-
    (   side_to_move(FEN, Color),
        fen_to_board(FEN, Board0),
        uci_parse(Move, sq(SF,SR), sq(TF,TR), Promo)
    ->  (   move_legal(Board0, Color, Move)
        ->  apply_move_pure(Board0, sq(SF,SR), sq(TF,TR), Promo, After),
            evaluate_claims(After, Claims, true, Results),
            emit_verdict(true, Results)
        ;   evaluate_claims(Board0, Claims, false, Results),
            emit_verdict(false, Results)
        )
    ;   write_error("invalid fen or move")
    ).

emit_verdict(Legal, Results) :-
    write(current_output, '{"move_legal":'),
    (   Legal = true -> write(current_output, 'true')
    ;   write(current_output, 'false')
    ),
    write(current_output, ',"results":'),
    json_write(current_output, Results),
    write(current_output, '}').

evaluate_claims(_Board, [], _Legal, []).
evaluate_claims(Board, [Claim|Rest], Legal, [Verdict|RestV]) :-
    get_field(Claim, id, Id),
    get_field(Claim, type, Type),
    get_field(Claim, subject, S),
    get_field(Claim, object, O),
    (   Legal = false
    ->  V = unknown
    ;   claim_holds(Board, Type, S, O)
    ->  V = true
    ;   claim_refutes(Board, Type, S, O)
    ->  V = false
    ;   V = unknown
    ),
    Verdict = json([id=Id, verdict=V]),
    evaluate_claims(Board, Rest, Legal, RestV).

write_error(Msg) :-
    write(current_output, '{"error":"'), write(current_output, Msg), write(current_output, '"}').

% get_field: extract a field from a JSON object term (json-wrapped or plain list)
get_field(Term, Name, Value) :-
    (   Term = json(KVs), member(Name = Value, KVs)
    ;   member(Name = Value, Term)
    ).

:- initialization(main, main).
