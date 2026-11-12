% claims.pl - Claim evaluation on the AFTER-move board.
% Each claim type has holds/4 (provably true) and/or refutes/4 (provably false).
% When neither holds nor refutes, the checker returns unknown (three-valued logic).
% Board: list of piece(Type, Color, File, Rank).  Squares are atoms like "e5".

:- module(claims, [
    claim_holds/4,
    claim_refutes/4
]).

:- use_module(board).
:- use_module(library(lists)).

opp(white, black). opp(black, white).

sign(0, 0). sign(X, 1) :- X > 0. sign(X, -1) :- X < 0.
neg(X, Y) :- Y is -X.

%-------------------------------------------------------------------------
% Dispatcher
%-------------------------------------------------------------------------
claim_holds(Board, attacks, S, O) :-
    attack_claim(Board, S, O).
claim_holds(Board, controls_square, S, O) :-
    attack_claim(Board, S, O).
claim_holds(Board, defends, S, O) :-
    attack_claim(Board, S, O),
    piece_at_sq(Board, S, piece(_, C)),
    piece_at_sq(Board, O, piece(_, C)).
claim_holds(Board, threatens, S, O) :-
    attack_claim(Board, S, O),
    piece_at_sq(Board, S, piece(_, C)),
    piece_at_sq(Board, O, piece(_, OC)),
    opp(C, OC).
claim_holds(Board, forks, S, O) :-
    square_to_file_rank(S, sq(SF, SR)),
    square_to_file_rank(O, sq(OF, OR)),
    piece_at_sq(Board, S, piece(_, C)),
    opp(C, Enemy),
    piece_at_sq(Board, O, piece(_, Enemy)),
    piece_attacks_square(Board, SF, SR, _, C, OF, OR),
    fork_has_second_target(Board, SF, SR, C, Enemy, OF, OR).
claim_holds(Board, pins, S, O) :-
    pin_holds(Board, S, O).
claim_holds(Board, blocks, S, O) :-
    block_holds(Board, S, O).
claim_holds(Board, opens_line, S, O) :-
    opens_line_holds(Board, S, O).

% attack_claim: piece at Subject attacks Object square
attack_claim(Board, S, O) :-
    square_to_file_rank(S, sq(SF, SR)),
    square_to_file_rank(O, sq(TF, TR)),
    piece_at_sq(Board, S, piece(Type, C)),
    piece_attacks_square(Board, SF, SR, Type, C, TF, TR).

fork_has_second_target(Board, SF, SR, C, Enemy, OF, OR) :-
    between(1, 8, TF), between(1, 8, TR),
    \+ (TF =:= OF, TR =:= OR),
    piece_at(Board, TF, TR, piece(_, Enemy)),
    piece_attacks_square(Board, SF, SR, _, C, TF, TR).

%-------------------------------------------------------------------------
% Refutes (provably false)
%-------------------------------------------------------------------------
claim_refutes(Board, attacks, S, O) :-
    (   \+ piece_at_sq(Board, S, piece(_, _))
    ->  true
    ;   square_to_file_rank(S, sq(SF, SR)),
        square_to_file_rank(O, sq(TF, TR)),
        piece_at(Board, SF, SR, piece(Type, C)),
        \+ piece_attacks_square(Board, SF, SR, Type, C, TF, TR)
    ).
claim_refutes(Board, controls_square, S, O) :-
    claim_refutes(Board, attacks, S, O).
claim_refutes(Board, defends, S, O) :-
    (   \+ attack_claim(Board, S, O)
    ->  true
    ;   piece_at_sq(Board, S, piece(_, C)),
        (   \+ piece_at_sq(Board, O, piece(_, _))
        ;   piece_at_sq(Board, O, piece(_, OC)), \+ opp(C, OC)
        )
    ).
claim_refutes(Board, threatens, S, O) :-
    true.
claim_refutes(Board, forks, S, O) :-
    (   \+ piece_at_sq(Board, S, piece(_, _))
    ->  true
    ;   square_to_file_rank(S, sq(SF, SR)),
        square_to_file_rank(O, sq(OF, OR)),
    piece_at_sq(Board, S, piece(_, C)),
    opp(C, Enemy),
    (   \+ piece_at_sq(Board, O, piece(_, Enemy))
    ;   \+ piece_attacks_square(Board, SF, SR, _, C, OF, OR)
    ;   \+ fork_has_second_target(Board, SF, SR, C, Enemy, OF, OR)
    )
    ).
% pins, blocks, opens_line: no refutes -> unknown when not provable (safe).

%-------------------------------------------------------------------------
% pins: piece S pinned to king O (S blocks an enemy slider attack on king O)
%-------------------------------------------------------------------------
pin_holds(Board, S, O) :-
    square_to_file_rank(S, sq(SF, SR)),
    square_to_file_rank(O, sq(OF, OR)),
    S \= O,
    piece_at_sq(Board, O, piece(king, C)),
    piece_at_sq(Board, S, piece(_, C)),
    \+ in_check(Board, C, sq(OF, OR)),      % king not currently in check
    opp(C, Enemy),
    (   SF =:= OF ; SR =:= OR ; abs(SF - OF) =:= abs(SR - OR) ),
    sign(SF - OF, SDF), sign(SR - OR, SDR),
    F1 is SF + SDF, R1 is SR + SDR,
    find_enemy_slider_beyond(Board, F1, R1, SDF, SDR, sq(OF, OR), Enemy, sq(SF, SR)).

find_enemy_slider_beyond(Board, F, R, SDF, SDR, O, Enemy, S) :-
    (   on_board(F, R)
    ->  (   piece_at(Board, F, R, piece(EType, Enemy)),
            slide_dir(EType, _, _),          % E must be a slider
            neg(SDF, NSDF), neg(SDR, NSDR),
            F2 is F + NSDF, R2 is R + NSDR,
            ray_clear_to_sq(Board, F2, R2, NSDF, NSDR, O, S)
        ->  true
        ;   empty_square(Board, F, R),
            F2 is F + SDF, R2 is R + SDR,
            find_enemy_slider_beyond(Board, F2, R2, SDF, SDR, O, Enemy, S)
        )
    ;   fail
    ).

% ray_clear_to_sq: walk from just-past-E toward O.
% Require empty squares, except S (the pinned piece) which may be occupied.
% Terminate successfully upon reaching O.
ray_clear_to_sq(_Board, F, R, _, _, O, _S) :-
    sq(F, R) = O.                                  % reached O (target) -> OK
ray_clear_to_sq(_Board, F, R, _, _, _O, S) :-
    sq(F, R) = S.                                  % reached S (blocker) -> OK
ray_clear_to_sq(Board, F, R, DF, DR, O, S) :-
    on_board(F, R),
    \+ sq(F, R) = O,
    \+ sq(F, R) = S,
    empty_square(Board, F, R),
    F1 is F + DF, R1 is R + DR,
    ray_clear_to_sq(Board, F1, R1, DF, DR, O, S).

%-------------------------------------------------------------------------
% blocks: piece S blocks an enemy slider attack on square O
% (S lies between an enemy slider E and O; remove S and O becomes attacked)
%-------------------------------------------------------------------------
block_holds(Board, S, O) :-
    square_to_file_rank(S, sq(SF, SR)),
    square_to_file_rank(O, sq(OF, OR)),
    S \= O,
    (   SF =:= OF ; SR =:= OR ; abs(SF - OF) =:= abs(SR - OR) ),
    sign(SF - OF, SDF), sign(SR - OR, SDR),
    (   SDF =:= 0, SDR =:= 0 -> fail ; true ),
    F1 is SF + SDF, R1 is SR + SDR,
    find_enemy_slider_beyond(Board, F1, R1, SDF, SDR, sq(OF, OR), _, sq(SF, SR)).

%-------------------------------------------------------------------------
% opens_line: piece S is a slider with a clear line to O
%-------------------------------------------------------------------------
opens_line_holds(Board, S, O) :-
    square_to_file_rank(S, sq(SF, SR)),
    square_to_file_rank(O, sq(OF, OR)),
    S \= O,
    piece_at_sq(Board, S, piece(Type, _)),
    member(Type, [rook, bishop, queen]),
    (   SF =:= OF ; SR =:= OR ; abs(SF - OF) =:= abs(SR - OR) ),
    sign(OF - SF, SDF), sign(OR - SR, SDR),
    F1 is SF + SDF, R1 is SR + SDR,
    ray_clear_to_sq(Board, F1, R1, SDF, SDR, sq(OF, OR), dummy_sq).

dummy_sq("zz").
