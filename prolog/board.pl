% board.pl - FEN parsing, board representation, move legality
% Board: list of piece(Type, Color, File, Rank)  (File,Rank: 1..8)

:- module(board, [
    fen_to_board/2,              % +FEN, -Board
    side_to_move/2,              % +FEN, -Color (white/black)
    square_to_file_rank/2,       % +SquareAtom("e5"), -sq(File,Rank)
    file_rank_to_square/2,       % +sq(File,Rank), -SquareAtom
    piece_at/4,                  % +Board, +File, +Rank, -piece(Type,Color)
    piece_at_sq/3,               % +Board, +SquareAtom, -piece(Type,Color)
    empty_square/3,              % +Board, +File, +Rank
    king_square/3,               % +Board, +Color, -sq(File,Rank)
    in_check/3,                  % +Board, +Color, +sq(File,Rank)
    uci_parse/4,                 % +MoveAtom("g1f3"), -sq(SF,SR), -sq(TF,TR), -Promo
    piece_can_move/8,            % +Board, +Type, +Color, +SF, +SR, +TF, +TR, +Promo
    apply_move_pure/5,           % +Board, +sq(SF,SR), +sq(TF,TR), +Promo, -NewBoard
    move_legal/3,                % +Board, +Color, +MoveAtom
    apply_move/5,                % +Board, +Color, +MoveAtom, -NewBoard, -Legal
    piece_attacks_square/7,      % +Board, +SF,+SR,+Type,+Color,+TF,+TR
    slide_dir/3,                  % +Type, +FileDelta, +RankDelta
    on_board/2                    % +File, +Rank
]).

:- use_module(library(lists)).

%-------------------------------------------------------------------------
% File <-> int (a=1..h=8)
%-------------------------------------------------------------------------
file_int(a,1). file_int(b,2). file_int(c,3). file_int(d,4).
file_int(e,5). file_int(f,6). file_int(g,7). file_int(h,8).
rank_int('1',1). rank_int('2',2). rank_int('3',3). rank_int('4',4).
rank_int('5',5). rank_int('6',6). rank_int('7',7). rank_int('8',8).
int_to_file(1,a). int_to_file(2,b). int_to_file(3,c). int_to_file(4,d).
int_to_file(5,e). int_to_file(6,f). int_to_file(7,g). int_to_file(8,h).

square_to_file_rank(S, sq(F,R)) :-
    atom_chars(S, [Fc, Rc]),
    file_int(Fc, F),
    rank_int(Rc, R).

file_rank_to_square(sq(F,R), S) :-
    int_to_file(F, Fc),
    char_code(R+48, Rc),
    atom_chars(S, [Fc, Rc]).

%-------------------------------------------------------------------------
% FEN parsing: placement + side to move
%-------------------------------------------------------------------------
fen_to_board(FEN, Board) :-
    split_string(FEN, " ", "", [Placement, Side, Castling, EP, Hm, Fm]),
    fen_placement_to_pieces(Placement, Pieces),
    Board = Pieces.

side_to_move(FEN, Color) :-
    split_string(FEN, " ", "", [_, Side, _, _, _, _]),
    (   Side = "w" -> Color = white ; Color = black ).

fen_placement_to_pieces(Placement, Pieces) :-
    split_string(Placement, "/", "", Rows),
    fen_rows_to_pieces(Rows, 8, Pieces).

fen_rows_to_pieces([], _, []).
fen_rows_to_pieces([Row|Rows], Rank, Pieces) :-
    fen_row_to_pieces(Row, 1, Rank, RowPieces),
    Rank1 is Rank - 1,
    fen_rows_to_pieces(Rows, Rank1, RestPieces),
    append(RowPieces, RestPieces, Pieces).

fen_row_to_pieces(Row, File, Rank, Pieces) :-
    atom_chars(Row, Chars),
    fen_row_chars(Chars, File, Rank, Pieces).

fen_row_chars([], _, _, []).
fen_row_chars([C|Cs], File, Rank, Pieces) :-
    (   char_type(C, alpha)
    ->  atom_chars(Pa, [C]),
        fen_piece(Pa, Type, Color),
        Pieces = [piece(Type, Color, File, Rank)|Rest],
        File1 is File + 1,
        fen_row_chars(Cs, File1, Rank, Rest)
    ;   char_type(C, digit)
    ->  char_code(C, Cc),
        Empty is Cc - 48,
        File1 is File + Empty,
        fen_row_chars(Cs, File1, Rank, Pieces)
    ;   fen_row_chars(Cs, File, Rank, Pieces)
    ).

fen_piece('P', pawn, white). fen_piece('N', knight, white). fen_piece('B', bishop, white).
fen_piece('R', rook, white). fen_piece('Q', queen, white). fen_piece('K', king, white).
fen_piece('p', pawn, black). fen_piece('n', knight, black). fen_piece('b', bishop, black).
fen_piece('r', rook, black). fen_piece('q', queen, black). fen_piece('k', king, black).

%-------------------------------------------------------------------------
% Board queries
%-------------------------------------------------------------------------
piece_at(Board, File, Rank, piece(Type, Color)) :-
    member(piece(Type, Color, File, Rank), Board).

piece_at_sq(Board, Square, piece(Type, Color)) :-
    square_to_file_rank(Square, sq(File, Rank)),
    format('  DBG piece_at_sq: Square=~w File=~w Rank=~w Board=~w~n', [Square, File, Rank, Board]),
    piece_at(Board, File, Rank, piece(Type, Color)),
    format('  DBG piece_at: Type=~w Color=~w~n', [Type, Color]).

empty_square(Board, File, Rank) :-
    \+ memberchk(piece(_, _, File, Rank), Board).

king_square(Board, Color, sq(File, Rank)) :-
    member(piece(king, Color, File, Rank), Board).

%-------------------------------------------------------------------------
% Attack geometry
%-------------------------------------------------------------------------
slide_dir(rook,  1, 0). slide_dir(rook,  -1, 0). slide_dir(rook,  0, 1). slide_dir(rook,  0, -1).
slide_dir(bishop, 1, 1). slide_dir(bishop, 1, -1). slide_dir(bishop, -1, 1). slide_dir(bishop, -1, -1).
slide_dir(queen,  1, 0). slide_dir(queen,  -1, 0). slide_dir(queen,  0, 1). slide_dir(queen,  0, -1).
slide_dir(queen,  1, 1). slide_dir(queen,  1, -1). slide_dir(queen, -1, 1). slide_dir(queen, -1, -1).

knight_move(1, 2). knight_move(2, 1). knight_move(1, -2). knight_move(2, -1).
knight_move(-1, 2). knight_move(-2, 1). knight_move(-1, -2). knight_move(-2, -1).

pawn_dir(white, 1). pawn_dir(black, -1).
pawn_start_rank(white, 2). pawn_start_rank(black, 7).
pawn_promotion_rank(white, 8). pawn_promotion_rank(black, 1).

on_board(File, Rank) :- between(1, 8, File), between(1, 8, Rank).

% Does piece (Type,Color) at (SF,SR) attack square (TF,TR) on Board?
piece_attacks_square(Board, SF, SR, Type, Color, TF, TR) :-
    piece_at(Board, SF, SR, piece(Type, Color)),
    on_board(TF, TR),
    (   Type = knight,
        knight_move(DF, DR), TF is SF + DF, TR is SR + DR
    ;   Type = pawn,
        pawn_dir(Color, PDir),
        (   TF is SF - 1 ; TF is SF + 1 ),
        TR is SR + PDir
    ;   slide_dir(Type, SDF, SDR),
        F1 is SF + SDF, R1 is SR + SDR,
        slide_ray(Board, F1, R1, SDF, SDR, TF, TR)
    ).

slide_ray(Board, F, R, SDF, SDR, TF, TR) :-
    on_board(F, R),
    (   F =:= TF, R =:= TR -> true
    ;   empty_square(Board, F, R),
        F1 is F + SDF, R1 is R + SDR,
        slide_ray(Board, F1, R1, SDF, SDR, TF, TR)
    ).

attacker_at(Board, SF, SR, TF, TR, Color) :-
    piece_at(Board, SF, SR, piece(Type, Color)),
    piece_attacks_square(Board, SF, SR, Type, Color, TF, TR).

square_attacked_by(Board, TF, TR, ByColor) :-
    on_board(TF, TR),
    between(1, 8, SF), between(1, 8, SR),
    attacker_at(Board, SF, SR, TF, TR, ByColor).

in_check(Board, Color, sq(KF, KR)) :-
    king_square(Board, Color, sq(KF, KR)),
    (   Color = white -> Enemy = black ; Enemy = white ),
    square_attacked_by(Board, KF, KR, Enemy).

%-------------------------------------------------------------------------
% UCI move parse "g1f3" / "e7e8q"
%-------------------------------------------------------------------------
uci_parse(Move, sq(SF,SR), sq(TF,TR), Promo) :-
    atom_chars(Move, [Fc, Rc, Fc2, Rc2 | Rest]),
    file_int(Fc, F), rank_int(Rc, SR),
    file_int(Fc2, F2), rank_int(Rc2, TR),
    SF = F, TF = F2,
    (   Rest = [Pc]
    ->  (   Pc = 'q' -> Promo = queen
        ;   Pc = 'r' -> Promo = rook
        ;   Pc = 'b' -> Promo = bishop
        ;   Pc = 'n' -> Promo = knight
        ;   Promo = none
        )
    ;   Promo = none
    ).

%-------------------------------------------------------------------------
% Can a piece move (geometry + capture rules), ignoring check
%-------------------------------------------------------------------------
piece_can_move(Board, pawn, Color, SF, SR, TF, TR, none) :-
    pawn_dir(Color, PDir),
    (   TF =:= SF, TR is SR + PDir, empty_square(Board, TF, TR)        % single forward
    ;   abs(SF - TF) =:= 1, TR is SR + PDir,                            % capture
        piece_at(Board, TF, TR, piece(_, OColor)),
        piece_at(Board, SF, SR, piece(_, Color)),
        OColor \= Color
    ;   TF =:= SF,                                                      % double from start
        pawn_start_rank(Color, SR),
        TR is SR + 2 * PDir,
        empty_square(Board, TF, TR),
        Mid is SR + PDir,
        empty_square(Board, TF, Mid)
    ).

piece_can_move(Board, knight, _Color, SF, SR, TF, TR, _Promo) :-
    knight_move(DF, DR), TF is SF + DF, TR is SR + DR,
    (   empty_square(Board, TF, TR)
    ;   piece_at(Board, SF, SR, piece(_, Color)),
        piece_at(Board, TF, TR, piece(_, OColor)),
        OColor \= Color
    ).

piece_can_move(Board, bishop, _Color, SF, SR, TF, TR, _Promo) :-
    abs(SF - TF) =:= abs(SR - TR),
    slide_path_clear(Board, SF, SR, TF, TR),
    (   empty_square(Board, TF, TR)
    ;   piece_at(Board, SF, SR, piece(_, Color)),
        piece_at(Board, TF, TR, piece(_, OColor)),
        OColor \= Color
    ).

piece_can_move(Board, rook, _Color, SF, SR, TF, TR, _Promo) :-
    (   SF =:= TF ; SR =:= TR ),
    slide_path_clear(Board, SF, SR, TF, TR),
    (   empty_square(Board, TF, TR)
    ;   piece_at(Board, SF, SR, piece(_, Color)),
        piece_at(Board, TF, TR, piece(_, OColor)),
        OColor \= Color
    ).

piece_can_move(Board, queen, _Color, SF, SR, TF, TR, _Promo) :-
    (   SF =:= TF ; SR =:= TR ; abs(SF - TF) =:= abs(SR - TR) ),
    slide_path_clear(Board, SF, SR, TF, TR),
    (   empty_square(Board, TF, TR)
    ;   piece_at(Board, SF, SR, piece(_, Color)),
        piece_at(Board, TF, TR, piece(_, OColor)),
        OColor \= Color
    ).

piece_can_move(Board, king, _Color, SF, SR, TF, TR, _Promo) :-
    abs(SF - TF) =< 1, abs(SR - TR) =< 1,
    (SF \= TF ; SR \= TR),
    (   empty_square(Board, TF, TR)
    ;   piece_at(Board, SF, SR, piece(_, Color)),
        piece_at(Board, TF, TR, piece(_, OColor)),
        OColor \= Color
    ).

% promotion
piece_can_move(Board, pawn, Color, SF, SR, TF, TR, Promo) :-
    pawn_dir(Color, PDir),
    pawn_promotion_rank(Color, TR),
    Promo \= none,
    (   TF =:= SF, TR is SR + PDir, empty_square(Board, TF, TR)
    ;   abs(SF - TF) =:= 1, TR is SR + PDir,
        piece_at(Board, TF, TR, piece(_, OColor)),
        OColor \= Color
    ).

slide_path_clear(Board, SF, SR, TF, TR) :-
    (   SF =:= TF
    ->  (   TR > SR -> Dir = 1 ; Dir = -1 ),
        R1 is SR + Dir,
        file_clear(Board, SF, R1, TR, Dir)
    ;   SR =:= TR
    ->  (   TF > SF -> Dir = 1 ; Dir = -1 ),
        F1 is SF + Dir,
        rank_clear(Board, F1, SR, TF, Dir)
    ;   abs(SF - TF) =:= abs(SR - TR),
        (   TF > SF -> FDir = 1 ; FDir = -1 ),
        (   TR > SR -> RDir = 1 ; RDir = -1 ),
        F1 is SF + FDir, R1 is SR + RDir,
        diag_clear(Board, F1, R1, TF, TR, FDir, RDir)
    ).

file_clear(_Board, _F, TR, TR, _) :- !.
file_clear(Board, F, R, TR, Dir) :-
    on_board(F, R),
    empty_square(Board, F, R),
    R1 is R + Dir,
    file_clear(Board, F, R1, TR, Dir).

rank_clear(_Board, F, _R, TF, _) :- F =:= TF, !.
rank_clear(Board, F, R, TF, Dir) :-
    on_board(F, R),
    empty_square(Board, F, R),
    F1 is F + Dir,
    rank_clear(Board, F1, R, TF, Dir).

diag_clear(_Board, TF, TR, TF, TR, _, _) :- !.
diag_clear(Board, F, R, TF, TR, FDir, RDir) :-
    on_board(F, R),
    empty_square(Board, F, R),
    F1 is F + FDir, R1 is R + RDir,
    diag_clear(Board, F1, R1, TF, TR, FDir, RDir).

%-------------------------------------------------------------------------
% Apply move (pure)
%-------------------------------------------------------------------------
apply_move_pure(Board, sq(SF,SR), sq(TF,TR), Promo, NewBoard) :-
    piece_at(Board, SF, SR, piece(Type, Color)),
    (   Promo = none -> NewType = Type ; NewType = Promo ),
    delete(Board, piece(Type, Color, SF, SR), Rest1),
    (   member(piece(_, _, TF, TR), Rest1)
    ->  delete(Rest1, piece(_, _, TF, TR), Rest2)
    ;   Rest2 = Rest1
    ),
    NewBoard = [piece(NewType, Color, TF, TR)|Rest2].

%-------------------------------------------------------------------------
% Move legality: geometry + not leaving king in check
%-------------------------------------------------------------------------
move_legal(Board, Color, Move) :-
    uci_parse(Move, sq(SF,SR), sq(TF,TR), Promo),
    piece_at(Board, SF, SR, piece(Type, Color)),
    piece_can_move(Board, Type, Color, SF, SR, TF, TR, Promo),
    apply_move_pure(Board, sq(SF,SR), sq(TF,TR), Promo, After),
    king_square(Board, Color, sq(KF,KR)),
    (   KF =:= SF, KR =:= SR
    ->  king_square(After, Color, sq(TF,TR)),
        \+ in_check(After, Color, sq(TF,TR))
    ;   \+ in_check(After, Color, sq(KF,KR))
    ).

apply_move(Board, Color, Move, NewBoard, Legal) :-
    (   move_legal(Board, Color, Move)
    ->  uci_parse(Move, sq(SF,SR), sq(TF,TR), Promo),
        apply_move_pure(Board, sq(SF,SR), sq(TF,TR), Promo, NewBoard),
        Legal = true
    ;   Legal = false
    ).

apply_move(Board, _Color, Move, _NewBoard, false) :-
    \+ (uci_parse(Move, _, _, _), piece_at(Board, _, _, _)).
