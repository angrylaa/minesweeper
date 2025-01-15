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

CREATE OR REPLACE FUNCTION print_state() LANGUAGE plpgsql AS
BEGIN
  RAISE NOTICE '%';
END

WITH RECURSIVE t(i) AS (
    -- non-recursive term
    SELECT 1
    UNION ALL
    -- recursive term
    SELECT i + 1 -- takes i of the previous row and adds 1
    SELECT print_state()
    FROM t -- self-reference that enables recursion
    WHERE i < 100 -- when i = 5, the CTE stops
)
SELECT *
FROM t;