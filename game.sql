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

-- CREATE TABLE minefield_placements(
--         A BOOLEAN DEFAULT 0,
--         B BOOLEAN DEFAULT 0,
--         C BOOLEAN DEFAULT 0,
--         D BOOLEAN DEFAULT 0,
--         E BOOLEAN DEFAULT 0,
--         F BOOLEAN DEFAULT 0,
--         G BOOLEAN DEFAULT 0,
--         H BOOLEAN DEFAULT 0,
--         I BOOLEAN DEFAULT 0,
--         J BOOLEAN DEFAULT 0,
--         K BOOLEAN DEFAULT 0,
--         L BOOLEAN DEFAULT 0,
--         M BOOLEAN DEFAULT 0,
--         N BOOLEAN DEFAULT 0,
--         O BOOLEAN DEFAULT 0,
--         P BOOLEAN DEFAULT 0
--     )

-- recursive function that places the mines

WITH RECURSIVE total_mines AS 
(
    SELECT 40 AS mines
    UNION ALL
    select mines - 1 from total_mines
    WHERE mines > 0 --> catcher value to prevent infinte loop
) 

SELECT * FROM total_mines;

-- create a view based on the minefield which has numbers representing nearby bombs