% Golden tests for Track A claim checker (A5).
% claim(Id, Type, Subject, Object, Expected)
%   Expected: true  -> claim_holds must succeed
%             false -> claim_refutes must succeed

:- module(golden_tests, [run_tests/0]).
:- use_module('../prolog/board').
:- use_module('../prolog/claims').

run_tests :-
    tests(Tests),
    maplist(run_claim, Tests).

run_claims(Name, After, [claim(Id, Type, S, O, Expected)|Rest]) :-
    (   Expected = true
    ->  (   claims:claim_holds(After, Type, S, O)
        ->  true
        ;   format('~w: CONFIDENT-WRONG TRUE for claim ~w (~w,~w,~w)~n',
                   [Name, Id, Type, S, O]),
            fail
        )
    ;   Expected = false
    ->  (   claims:claim_refutes(After, Type, S, O)
        ->  true
        ;   format('~w: CONFIDENT-WRONG FALSE for claim ~w (~w,~w,~w)~n',
                   [Name, Id, Type, S, O]),
            fail
        )
    ;   true
    ),
    run_claims(Name, After, Rest).
run_claims(_, _, []).

tests([
    % Easy position: white pawn e4 attacks d5 and f5, not e5
    t(start_e4e4,
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1', 'e2e4', white,
        [ claim(c1, attacks, e4, d5, true),
          claim(c2, attacks, e4, f5, true),
          claim(c3, attacks, e4, e5, false),
          claim(c4, controls_square, e4, d5, true),
          claim(c5, defends, e4, e5, false) ]),

    % Black to move e7e5: black pawn attacks d4 and f4
    t(black_e7e5,
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1', 'e7e5', black,
        [ claim(c1, attacks, e5, d4, true),
          claim(c2, attacks, e5, f4, true),
          claim(c3, controls_square, e5, d4, true),
          claim(c4, defends, e5, d4, false) ]),

    % Rook on open file: rook d5 attacks d1, d8, a5
    t(rook_open_file,
        '4k3/8/8/8/3R4/8/8/4K3 w - - 0 1', 'd4d5', white,
        [ claim(c1, attacks, d5, d1, true),
          claim(c2, attacks, d5, d8, true),
          claim(c3, attacks, d5, a5, true),
          claim(c4, controls_square, d5, d1, true) ]),

    % Bishop diagonal: bishop e5 attacks a1 and h8
    t(bishop_diagonal,
        '4k3/8/8/8/3B4/8/8/4K3 w - - 0 1', 'd4e5', white,
        [ claim(c1, attacks, e5, a1, true),
          claim(c2, attacks, e5, h8, true),
          claim(c3, controls_square, e5, h8, true) ]),

    % Queen center: queen e5 attacks a1, e1, a5
    t(queen_center,
        '4k3/8/8/8/3Q4/8/8/4K3 w - - 0 1', 'd4e5', white,
        [ claim(c1, attacks, e5, a1, true),
          claim(c2, attacks, e5, e1, true),
          claim(c3, attacks, e5, a5, true),
          claim(c4, threatens, e5, e1, false) ]),

    % Threatens: queen e5 does not threaten empty e1
    t(threatens_empty,
        '4k3/8/8/8/3Q4/8/8/4K3 w - - 0 1', 'd4e5', white,
        [ claim(c1, threatens, e5, e1, false) ]),

    % Knight fork: knight d4 forks rooks e2 and f3
    t(fork_knight,
        '4k3/8/8/8/3N4/5r2/4r3/7K w - - 0 1', 'h1g1', white,
        [ claim(c1, forks, d4, e2, true) ]),

    % Pin: bishop g5 pins knight f6 to king e7
    t(pin_knight_to_king,
        '8/4k3/5n2/6B1/8/8/4K3/8 w - - 0 1', 'e2e3', white,
        [ claim(c1, pins, f6, e7, true) ]),

    % Blocks: rook e4 blocks rook e1 attack on d4
    t(blocks_rook_line,
        '4k3/8/8/8/8/8/PPPPPPPP/4K3 w - - 0 1', 'e2e4', white,
        [ claim(c1, blocks, e4, d5, unknown )]).