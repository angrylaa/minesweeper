-- SQL implementation of minesweeper

-- main game loop is a recusive CTE which updates whenever the user enters input
-- if the table is empty -> we should fill it w/ algorithm
-- once table is full it should have a 16x16 board w/ 40 bombs
-- we should have 2 tables, one that's the final answer & one that is tracking user input

-- [ ] [ ] [ ] [ ] --> these are all empty
-- [1] [2] [3] [4] --> these will represent the tiles
-- [F] --> user flagged that tile
-- [X] --> marks bombs (should not be shown to user)

-- zero-open -> this is how to start the game (if a revealed cell is zero, reveal all its neighbours)
-- a 4 way flood -> how to determine when to show users tiles

-- CREATE OR REPLACE FUNCTION print_state() LANGUAGE plpgsql AS
-- BEGIN
--   RAISE NOTICE '%';
-- END

-- WITH RECURSIVE t(i) AS (
--     -- non-recursive term
--     SELECT 1
--     UNION ALL
--     -- recursive term
--     SELECT i + 1 -- takes i of the previous row and adds 1
--     SELECT print_state()
--     FROM t -- self-reference that enables recursion
--     WHERE i < 100 -- when i = 5, the CTE stops
-- )
-- SELECT *
-- FROM t;

-- 16 x 16 board w/ 40 mines
-- [A B C D E F G H I J K L M N O P]
-- [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
-- generate 40 unique combos from the list

-- one table for the bombs & numbers, generated at the beginning
-- one table for user inputs (navigating)
-- one table that is the visual display for the user

-- creates an initial table w/ default 0 representing whether a bomb is present 

DROP TABLE IF EXISTS minefield_placements;
CREATE TABLE IF NOT EXISTS minefield_placements(
        row_id SERIAL PRIMARY KEY,
        A VARCHAR(40) DEFAULT 0,
        B VARCHAR(40) DEFAULT 0,
        C VARCHAR(40) DEFAULT 0,
        D VARCHAR(40) DEFAULT 0,
        E VARCHAR(40) DEFAULT 0,
        F VARCHAR(40) DEFAULT 0,
        G VARCHAR(40) DEFAULT 0,
        H VARCHAR(40) DEFAULT 0,
        I VARCHAR(40) DEFAULT 0,
        J VARCHAR(40) DEFAULT 0,
        K VARCHAR(40) DEFAULT 0,
        L VARCHAR(40) DEFAULT 0,
        M VARCHAR(40) DEFAULT 0,
        N VARCHAR(40) DEFAULT 0,
        O VARCHAR(40) DEFAULT 0,
        P VARCHAR(40) DEFAULT 0
    );

INSERT INTO minefield_placements(A) VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0);

-- recursive function that places the mines
WITH RECURSIVE total_mines AS 
(
    SELECT 40 AS mines, floor(random() * 16) + 1 AS x, floor(random() * 15) + 1 AS y
    UNION ALL
    SELECT mines - 1, floor(random() * 16) + 1, floor(random() * 15) + 1 from total_mines
    WHERE mines > 0 --> catcher value to prevent infinte loop
)
-- SELECT * FROM minefield_placements mp LEFT JOIN total_mines tm ON mp.row_id = tm.x
UPDATE minefield_placements mp
SET
    A = CASE WHEN tm.y = 1 THEN 'x' ELSE A END,
    B = CASE WHEN tm.y = 2 THEN 'x' ELSE B END,
    C = CASE WHEN tm.y = 3 THEN 'x' ELSE C END,
    D = CASE WHEN tm.y = 4 THEN 'x' ELSE D END,
    E = CASE WHEN tm.y = 5 THEN 'x' ELSE E END,
    F = CASE WHEN tm.y = 6 THEN 'x' ELSE F END,
    G = CASE WHEN tm.y = 7 THEN 'x' ELSE G END,
    H = CASE WHEN tm.y = 8 THEN 'x' ELSE H END,
    I = CASE WHEN tm.y = 9 THEN 'x' ELSE I END,
    J = CASE WHEN tm.y = 10 THEN 'x' ELSE J END,
    K = CASE WHEN tm.y = 11 THEN 'x' ELSE K END,
    L = CASE WHEN tm.y = 12 THEN 'x' ELSE L END,
    M = CASE WHEN tm.y = 13 THEN 'x' ELSE M END,
    N = CASE WHEN tm.y = 14 THEN 'x' ELSE N END,
    O = CASE WHEN tm.y = 15 THEN 'x' ELSE O END,
    P = CASE WHEN tm.y = 16 THEN 'x' ELSE P END
FROM total_mines tm
WHERE mp.row_id = tm.x;

SELECT * FROM minefield_placements ORDER BY row_id;

-- create a table based on the minefield which has numbers representing nearby bombs