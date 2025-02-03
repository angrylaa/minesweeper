-- SQL implementation of minesweeper

-- main game loop is a recusive CTE which updates WHEN EXISTSever the user enters input
-- if the table is empty -> we should fill it w/ algorithm
-- once table is full it should have a 16x16 board w/ 40 bombs
-- we should have 2 tables, one that's the final answer & one that is tracking user input

-- [ ] [ ] [ ] [ ] --> these are all empty
-- [1] [2] [3] [4] --> these will represent the tiles
-- [F] --> user flagged that tile
-- [X] --> marks bombs (should not be shown to user)

-- zero-open -> this is how to start the game (if a revealed cell is zero, reveal all its neighbours)
-- a 4 way flood -> how to determine WHEN EXISTS to show users tiles

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
--     WHERE i < 100 -- WHEN EXISTS i = 5, the CTE stops
-- )
-- SELECT *
-- FROM t;

-- one table for the bombs & numbers, generated at the beginning
-- one table for user inputs (navigating)
-- one table that is the visual display for the user

-- creates an initial table w/ default 0 representing whether a bomb is present 

DROP TABLE IF EXISTS minefield;
CREATE TABLE IF NOT EXISTS minefield(
        row_id SERIAL PRIMARY KEY,
        "A" VARCHAR(40) DEFAULT 0,
        "B" VARCHAR(40) DEFAULT 0,
        "C" VARCHAR(40) DEFAULT 0,
        "D" VARCHAR(40) DEFAULT 0,
        "E" VARCHAR(40) DEFAULT 0,
        "F" VARCHAR(40) DEFAULT 0,
        "G" VARCHAR(40) DEFAULT 0,
        "H" VARCHAR(40) DEFAULT 0,
        "I" VARCHAR(40) DEFAULT 0,
        "J" VARCHAR(40) DEFAULT 0,
        "K" VARCHAR(40) DEFAULT 0,
        "L" VARCHAR(40) DEFAULT 0,
        "M" VARCHAR(40) DEFAULT 0,
        "N" VARCHAR(40) DEFAULT 0,
        "O" VARCHAR(40) DEFAULT 0,
        "P" VARCHAR(40) DEFAULT 0
    );

DROP TABLE IF EXISTS mine_table;

INSERT INTO minefield("A") VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0);

-- recursive function that places the mines
WITH RECURSIVE generate_mines AS 
(
    SELECT 40 AS mine_id, floor(random() * 16) + 1 AS x, floor(random() * 15) + 1 AS y
    UNION ALL
    SELECT mine_id - 1, floor(random() * 16) + 1, floor(random() * 15) + 1 from generate_mines
    WHERE mine_id > 0 --> catcher value to prevent infinte loop
) 
SELECT * INTO mine_table FROM generate_mines;

-- insert the bombs into the mine_table
CREATE OR REPLACE FUNCTION insert_bombs()
    RETURNS void
    LANGUAGE plpgsql AS $$
    DECLARE
        col_char CHAR(1);
        y_cord INTEGER := 0;
        x_cord INTEGER := 0;
    BEGIN
        FOR i IN 1..40 LOOP
            SELECT mt.y, mt.x
            INTO y_cord, x_cord
            FROM mine_table mt
            WHERE mt.mine_id = i;

            col_char := CHR(64 + y_cord);

            EXECUTE format('
                UPDATE minefield mf
                SET %I = $1
                WHERE mf.row_id = $2
            ', col_char) USING 'M', x_cord;
        END LOOP;
    END;
    $$;

SELECT * FROM insert_bombs();
-- SELECT * FROM minefield ORDER BY row_id;

-- function to count adjacent bombs
CREATE OR REPLACE FUNCTION count_adjacent_bombs(col_num int, row_num int)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    total_bomb_count INTEGER := 0;
    bomb_count INTEGER := 0;
    col_char CHAR(1);
BEGIN
    FOR i IN -1..1 LOOP -- check from top left
        FOR j IN -1..1 LOOP -- to bottom right
            IF i = 0 AND j = 0 THEN  -- skip the center cell
            ELSE
                col_char := CHR(64 + col_num + j);

                RAISE NOTICE 'Checking cell at row: %, column: % (col_char: %)', row_num + i, col_num + j, col_char;
                
                -- Check if the adjacent cell is a bomb
                EXECUTE format('
                    SELECT CASE WHEN %I = $1 THEN 1 ELSE 0 END 
                    FROM minefield 
                    WHERE row_id = $2
                ', col_char)
                INTO bomb_count
                USING 'M', row_num + i;

                RAISE NOTICE '% bombs found', bomb_count;
                
                total_bomb_count := total_bomb_count + bomb_count;

                RAISE NOTICE '% total bombs', total_bomb_count;
            END IF;
        END LOOP;
    END LOOP;

    RETURN total_bomb_count;
END;
$$;

CREATE OR REPLACE FUNCTION initial_count()
    RETURNS void
    LANGUAGE plpgsql AS $$
    DECLARE
        col_char CHAR(1);
        adj_bombs INTEGER := 0;
    BEGIN
        FOR r in 1..16 LOOP
            FOR c in 1..16 LOOP
                col_char := CHR(64 + c);

                SELECT * FROM count_adjacent_bombs(c, r)
                INTO adj_bombs;

                EXECUTE format('
                INSERT INTO minefield mf(%I)
                VALUES $1
                WHERE mf.row_id = $2', 
                col_char) USING adj_bombs, r;
            END LOOP;
        END LOOP;
    END;
$$;

SELECT * FROM initial_count();