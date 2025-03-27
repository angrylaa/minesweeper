-- ########################################
-- SET UP THE GAME TABLES & STARTING STATES
-- ########################################

-- minefield → defines actual bombs placement & map
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

-- contains all 40 mines & their coords
DROP TABLE IF EXISTS mine_table;
CREATE TABLE IF NOT EXISTS mine_table(
    mine_id INTEGER,
    x INTEGER,
    y INTEGER
);

-- user display is what is returned to the user & what they see
DROP TABLE IF EXISTS user_display;
CREATE TABLE IF NOT EXISTS user_display(
    row_id SERIAL PRIMARY KEY,
    "A" VARCHAR(40) DEFAULT '[ - ]',
    "B" VARCHAR(40) DEFAULT '[ - ]',
    "C" VARCHAR(40) DEFAULT '[ - ]',
    "D" VARCHAR(40) DEFAULT '[ - ]',
    "E" VARCHAR(40) DEFAULT '[ - ]',
    "F" VARCHAR(40) DEFAULT '[ - ]',
    "G" VARCHAR(40) DEFAULT '[ - ]',
    "H" VARCHAR(40) DEFAULT '[ - ]',
    "I" VARCHAR(40) DEFAULT '[ - ]',
    "J" VARCHAR(40) DEFAULT '[ - ]',
    "K" VARCHAR(40) DEFAULT '[ - ]',
    "L" VARCHAR(40) DEFAULT '[ - ]',
    "M" VARCHAR(40) DEFAULT '[ - ]',
    "N" VARCHAR(40) DEFAULT '[ - ]',
    "O" VARCHAR(40) DEFAULT '[ - ]',
    "P" VARCHAR(40) DEFAULT '[ - ]'
);

-- track the user's position
DROP TABLE IF EXISTS user_position;
CREATE TABLE IF NOT EXISTS user_position(
    id SERIAL PRIMARY KEY,
    positionX INTEGER NOT NULL,
    positionY INTEGER NOT NULL
);

-- track the user's last action
DROP TABLE IF EXISTS user_action;
CREATE TABLE IF NOT EXISTS user_action(
    id SERIAL PRIMARY KEY,
    positionX INTEGER NOT NULL,
    positionY INTEGER NOT NULL,
    action_type VARCHAR(40) NOT NULL
);

-- tracks all flags user places
DROP TABLE IF EXISTS flags;
CREATE TABLE IF NOT EXISTS flags(
    row_id SERIAL PRIMARY KEY,
    positionX INTEGER NOT NULL,
    positionY INTEGER NOT NULL
);

-- tracks what the tile under the user's current position is
-- this is used to ensure that once the user leaves that tile, the state is maintained
DROP TABLE IF EXISTS prev_tile;
CREATE TABLE IF NOT EXISTS prev_tile(
    row_id SERIAL PRIMARY KEY,
    prev VARCHAR(40)
);

-- used in recursive function during zero-open
-- cleared after zero open
DROP TABLE IF EXISTS visited;
CREATE TABLE IF NOT EXISTS visited(
    id SERIAL PRIMARY KEY,
    positionX INTEGER NOT NULL,
    positionY INTEGER NOT NULL
);

-- INSERT & BEGINNING STAGE OF TABLES
INSERT INTO minefield("A") VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0);
INSERT INTO user_display("A") VALUES ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]');
INSERT INTO user_action (positionX, positionY, action_type) VALUES (0,0,'N');
INSERT INTO prev_tile(prev) VALUES('[ - ]');

-- ########################################
-- ########### SET UP FUNCTIONS ###########
-- ########################################

-- ### FUNCTION: generate 40 unique mines
-- x_cord = stores the x-coordinate
-- y_cord = stores the y-coordinate
-- duplicate = boolean value, acts as a flag to indicate repeated bombs
-- total_bombs = counts bombs & condition to stop loop

CREATE OR REPLACE FUNCTION generate_mines()
    RETURNS void
    LANGUAGE plpgsql AS $$
    DECLARE
        x_cord INTEGER := 0;
        y_cord INTEGER := 0;
        duplicate INTEGER := 0;
        total_bombs INTEGER := 1;
    BEGIN
        WHILE total_bombs < 41 LOOP
            -- generates random value from 1 to 16
            y_cord = floor(random() * 16) + 1;
            x_cord = floor(random() * 16) + 1;

            -- selects the number of rows (0 or 1) that have the same coords
            -- as the generated values
            EXECUTE format('
                SELECT COUNT(*)
                FROM mine_table mt
                WHERE mt.x = $1 AND mt.y = $2
            ')
            INTO duplicate
            USING x_cord, y_cord; 

            -- if duplicate is false
            IF duplicate = 0 THEN
                -- insert the new bomb into the mine table
                INSERT INTO mine_table (mine_id, x, y)
                VALUES(total_bombs, x_cord, y_cord);

                -- iterate the bomb - if there's a duplicate bomb, this never gets iterated
                total_bombs = total_bombs + 1;
            END IF;
        END LOOP;
    END;
$$;

SELECT * FROM generate_mines();

-- ### FUNCTION: inserts the bombs into the mine_table
-- col_char = stored the character converted x-coord
-- x_cord = stores the x-cordinate
-- y_cord = stores the y-cordinate

CREATE OR REPLACE FUNCTION insert_bombs()
    RETURNS void
    LANGUAGE plpgsql AS $$
    DECLARE
        col_char CHAR(1);
        y_cord INTEGER := 0;
        x_cord INTEGER := 0;
    BEGIN
        FOR i IN 1..40 LOOP
            -- select the y-cord & x-cord from the mine_table
            SELECT mt.y, mt.x
            INTO y_cord, x_cord
            FROM mine_table mt
            WHERE mt.mine_id = i;

            -- convert the x_cord into a character
            col_char := CHR(64 + x_cord);

            -- update the mine_field using the character & y-cord
            EXECUTE format('
                UPDATE minefield mf
                SET %I = $1
                WHERE mf.row_id = $2
            ', col_char) USING 'M', y_cord;
        END LOOP;
    END;
    $$;

SELECT * FROM insert_bombs();

-- ### FUNCTION: counts the adjacent bombs beside each cell
-- total_bomb_count = stores the number of bombs near cell
-- col_char = stored the character converted x-coord
-- is_bomb = flag on whether the cell contains a bomb

CREATE OR REPLACE FUNCTION count_adjacent_bombs(x_cord int, y_cord int)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    total_bomb_count INTEGER := 0;
    is_bomb INTEGER := 0;
    col_char CHAR(1);
BEGIN
    FOR i IN -1..1 LOOP -- check from top left
        FOR j IN -1..1 LOOP -- to bottom right
            IF i = 0 AND j = 0 THEN  -- skip the center cell
            ELSE
                -- handles the edge cases so that if the cell is on the border, it skips the out of bounds columns / rows
                IF x_cord = 1 AND j = -1 OR x_cord = 16 AND j = 1 OR y_cord = 1 AND i = -1 OR y_cord = 16 AND i = 1 THEN
                ELSE
                    -- convert the x_cord into a character
                    col_char := CHR(64 + x_cord + j);
                    
                    -- checks if the cell is equal to 'M'
                    -- set 1 if there's a bomb, otherwise 0
                    EXECUTE format('
                        SELECT CASE WHEN %I = $1 THEN 1 ELSE 0 END 
                        FROM minefield 
                        WHERE row_id = $2
                    ', col_char)
                    INTO is_bomb
                    USING 'M', y_cord + i;
                    
                    -- add bombs to the total_bomb_count
                    total_bomb_count := total_bomb_count + is_bomb;
                END IF;
            END IF;
        END LOOP;
    END LOOP;

    -- returns the total_bomb_countd
    RETURN total_bomb_count;
END;
$$;

-- ### FUNCTION: initiates the count of adjacent bombs
-- col_char = stored the character converted x-cord
-- adj_bombs = stores the adjacent bombs

CREATE OR REPLACE FUNCTION initial_count()
    RETURNS void
    LANGUAGE plpgsql AS $$
    DECLARE
        col_char CHAR(1);
        adj_bombs INTEGER := 0;
    BEGIN
        -- for all 16 rows & columns
        FOR y_cord in 1..16 LOOP
            FOR x_cord in 1..16 LOOP
                -- convert the x_cord into a character
                col_char := CHR(64 + x_cord);

                -- count the adjacent bombs
                SELECT * FROM count_adjacent_bombs(x_cord, y_cord)
                INTO adj_bombs;

                -- update the value of that cell
                EXECUTE format('
                    UPDATE minefield mf
                    SET %I = $1
                    WHERE mf.row_id = $2 AND mf.%I != $3', 
                col_char, col_char) USING adj_bombs, y_cord, 'M';
            END LOOP;
        END LOOP;
    END;
$$;

SELECT initial_count();

-- ### FUNCTION: find the first cell that's has 0 bombs
-- col_char = stored the character converted x-oord
-- bomb_count = stores the bomb count of a cell
-- x_cord = tracks the x_cord
-- y_cord = tracks the y_cord

CREATE OR REPLACE FUNCTION startingPoint()
    RETURNS VOID AS $$
    DECLARE 
        col_char VARCHAR(1) := '';
        bomb_count VARCHAR(1) := 0;
        x_cord INTEGER := 1;
        y_cord INTEGER := 1;
    BEGIN
        LOOP
            LOOP
                -- convert the x_cord into a character
                col_char := CHR(64 + x_cord);
        
                -- find the bomb_count of the current cell
                -- starts at (1,1)
                EXECUTE format('
                    SELECT mf.%I
                    FROM minefield mf
                    WHERE row_id = $1', col_char)
                INTO bomb_count
                USING y_cord;

                -- if the bomb_count is 0
                IF bomb_count = '0' THEN
                    -- insert the starting position
                    INSERT INTO user_position (positionX, positionY) VALUES (x_cord, y_cord);

                    -- sets x_cord and y_cord to meet end conditions
                    x_cord := 15;
                    y_cord := 15;

                END IF;

                -- iterates the x-cord
                x_cord := x_cord + 1;

                -- end condition
                EXIT WHEN x_cord = 16;
            END LOOP;
            
            -- reset the col
            x_cord := 1;

            -- iterate the y-cord → starts at 1
            y_cord := y_cord + 1;

            -- end condition
            EXIT WHEN y_cord = 16;
        END LOOP;
    END
$$ LANGUAGE plpgsql;

SELECT startingPoint();

-- ########################################
-- ############ USER CONTROLS #############
-- ########################################


CREATE OR REPLACE FUNCTION move_up() RETURNS VOID AS $$
BEGIN
    UPDATE user_position
    SET positionY = positionY - 1
    WHERE id = 1 AND positionY != 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION move_down() RETURNS VOID AS $$
BEGIN
    UPDATE user_position
    SET positionY = positionY + 1
    WHERE id = 1 AND positionY != 16;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION move_left() RETURNS VOID AS $$
BEGIN
    UPDATE user_position
    SET positionX = positionX - 1
    WHERE id = 1 AND positionX != 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION move_right() RETURNS VOID AS $$
BEGIN
    UPDATE user_position
    SET positionX = positionX + 1
    WHERE id = 1 AND positionX != 16;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION flag() RETURNS VOID AS $$
DECLARE
    x_cord INTEGER := 0;
    y_cord INTEGER := 0;
BEGIN
    SELECT up.positionY, up.positionX
    INTO y_cord, x_cord
    FROM user_position up
    WHERE up.id = 1;

    UPDATE user_action
    SET positionY = y_cord, positionX = x_cord, action_type = 'F'
    WHERE id = 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark() RETURNS VOID AS $$
DECLARE
    x_cord INTEGER := 0;
    y_cord INTEGER := 0;
BEGIN
    SELECT up.positionY, up.positionX
    INTO y_cord, x_cord
    FROM user_position up
    WHERE up.id = 1;

    UPDATE user_action
    SET positionY = y_cord, positionX = x_cord, action_type = 'R'
    WHERE id = 1;
END;
$$ LANGUAGE plpgsql;

-- ########################################
-- ############## GAME LOOP ###############
-- ########################################

-- Game loop consists of 3 main functions called in this order:
-- 1. display_state() →	shows the current state of the board
    -- a. displays where the user is based on input
    -- b. calls enter_action() to account if an action is input
-- 2. enter_action() → considers 2 actions, R or F
    -- R → reveals a cell
    -- F → flags a cell as a bomb
-- 3. clear_movement() → this function resets the user position to reveal the cell under it

-- ### FUNCTION: performs an action
-- col_char = stored the character converted x-cord
-- current_cell_value = 
-- in_flag
-- update_value

CREATE OR REPLACE FUNCTION enter_action(x_cord int, y_cord int, uAct char) RETURNS VOID AS $$
DECLARE
    col_char VARCHAR(1) := '';
    current_cell_value VARCHAR(1) := '';
    in_flag INTEGER := 0;
    update_value VARCHAR(40) := '[ - ]';
BEGIN
    -- convert the x_cord into a character
    col_char := CHR(64 + x_cord);

    -- checks the value in the current cell
    EXECUTE format('
        SELECT mf.%I
        FROM minefield mf
        WHERE row_id = $1', col_char)
    INTO current_cell_value
    USING y_cord;
    
    -- if the bomb is 0 & the user tries to reveal
    IF current_cell_value = '0' AND uAct = 'R' THEN
        -- zero open & reveal nearest neighbour
        PERFORM nearest_neighbours(x_cord, y_cord);
    END IF;

    -- check if the current cell has a record in the flag table
    -- output: 0 → this cell has not been flagged
    -- output: 1  → this cell has been flagged
    SELECT count(*)
    FROM flags f
    WHERE f.positionX = x_cord AND f.positionY = y_cord
    INTO in_flag;

    -- find the previous value of the current cell before it's updated with X
    SELECT pt.prev
    INTO update_value
    FROM prev_tile pt
    WHERE pt.row_id = 1;

    RAISE NOTICE '%,%, FLAG AND UPDATE', in_flag, update_value;

    -- toggle flag
    -- the user presses the F key & the prev cell was unopened
    IF uAct = 'F' THEN
        RAISE NOTICE '%,%', in_flag, update_value;
        IF in_flag = 0 AND update_value = '[ - ]' THEN
            EXECUTE format('
                UPDATE user_display ud
                SET %I = $1
                WHERE ud.row_id = $2
            ', col_char) USING '[ F ]', y_cord;

            RAISE NOTICE 'updated, flag inserted';

            -- add the flag into the table
            INSERT INTO flags(positionX, positionY) VALUES(x_cord, y_cord);
        END IF;
        IF in_flag = 1 THEN
            -- if the
            EXECUTE format('
                UPDATE user_display ud
                SET %I = $1
                WHERE ud.row_id = $2
            ', col_char) USING '[ X ]', y_cord;

            RAISE NOTICE 'deleted';

            DELETE FROM flags WHERE positionX = x_cord AND positionY = y_cord;
        END IF;
    END IF;

    -- update the user_display with the [ X ] marker
    EXECUTE format('
        UPDATE user_display ud
        SET %I = $1
        WHERE ud.row_id = $2
    ', col_char) USING '[ X ]', y_cord;
END;
$$ LANGUAGE plpgsql;

-- ### FUNCTION: 
-- col_char = stored the character converted x-coord

CREATE OR REPLACE FUNCTION nearest_neighbours(x_cord int, y_cord int) RETURNS VOID AS $$
DECLARE
    col_char VARCHAR(1) := '';
    bomb_count VARCHAR(1) := '';
    is_visited INTEGER := 0;
BEGIN
    RAISE INFO 'NEAREST NEIGHBOUR RUNS';

    FOR i IN -1..1 LOOP -- check from top left
        FOR j IN -1..1 LOOP -- to bottom right
            IF i = 0 AND j = 0 THEN  -- skip the center cell
            ELSE
                IF x_cord = 1 AND j = -1 OR x_cord = 16 AND j = 1 OR y_cord = 1 AND i = -1 OR y_cord = 16 AND i = 1 THEN
                ELSE
                    col_char := CHR(64 + x_cord + j);

                    RAISE INFO '%, %', col_char, y_cord + i;

                    EXECUTE format('
                        SELECT mf.%I
                        FROM minefield mf
                        WHERE mf.row_id = $1', col_char)
                    INTO bomb_count
                    USING y_cord + i;

                    RAISE INFO '%', bomb_count;

                    EXECUTE format('
                        UPDATE user_display ud
                        SET %I = CASE
                            WHEN $1 = %L THEN %L
                            WHEN $1 = %L THEN %L
                            WHEN $1 = %L THEN %L
                            WHEN $1 = %L THEN %L
                            WHEN $1 = %L THEN %L
                            WHEN $1 = %L THEN %L
                            WHEN $1 = %L THEN %L
                            WHEN $1 = %L THEN %L
                            WHEN $1 = %L THEN %L
                            ELSE %I
                        END
                        WHERE ud.row_id = $2',
                        col_char, 
                        '0', '[ 0 ]',
                        '1', '[ 1 ]',
                        '2', '[ 2 ]',
                        '3', '[ 3 ]',
                        '4', '[ 4 ]',
                        '5', '[ 5 ]',
                        '6', '[ 6 ]',
                        '7', '[ 7 ]',
                        '8', '[ 8 ]',
                        col_char)
                    USING bomb_count, y_cord + i;

                    SELECT count(*)
                    FROM visited v
                    WHERE v.positionX = x_cord + j AND v.positionY = y_cord + i
                    INTO is_visited;

                    RAISE INFO '% VISITED BEFORE', is_visited; 

                    IF is_visited = 0 THEN
                        EXECUTE format('
                            INSERT INTO visited(positionX, positionY)
                            VALUES ($1, $2)
                        ')
                        USING x_cord + j, y_cord + i;

                        -- only recursive function IF the user display is [ - ] AKA untouched
                        IF bomb_count = '0' THEN
                            PERFORM nearest_neighbours(x_cord + j, y_cord + i);
                        END IF;
                    END IF;

                END IF;
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ### FUNCTION: 
-- col_char = stored the character converted x-coord

DROP FUNCTION display_state();
CREATE OR REPLACE FUNCTION display_state() RETURNS TABLE(
        "A" VARCHAR(40),
        "B" VARCHAR(40),
        "C" VARCHAR(40),
        "D" VARCHAR(40),
        "E" VARCHAR(40),
        "F" VARCHAR(40),
        "G" VARCHAR(40),
        "H" VARCHAR(40),
        "I" VARCHAR(40),
        "J" VARCHAR(40),
        "K" VARCHAR(40),
        "L" VARCHAR(40),
        "M" VARCHAR(40),
        "N" VARCHAR(40),
        "O" VARCHAR(40),
        "P" VARCHAR(40)
)
LANGUAGE plpgsql AS $$
#variable_conflict use_column
DECLARE
    x_cord INTEGER := 0;
    y_cord INTEGER := 0;
    col_char VARCHAR(1) := '';
    uAction VARCHAR(10) := '';
    previous VARCHAR(10) := '';
BEGIN
    SELECT up.positionY, up.positionX
    INTO y_cord, x_cord
    FROM user_position up
    WHERE up.id = 1;

    SELECT uA.action_type
    INTO uAction
    FROM user_action ua
    WHERE ua.id = 1;

    col_char := CHR(64 + x_cord);

    EXECUTE format('
        SELECT %I
        FROM user_display ud
        WHERE row_id = $1
    ', col_char)
    INTO previous
    USING y_cord;

    UPDATE prev_tile pt
    SET prev = previous
    WHERE pt.row_id = 1;

    PERFORM enter_action(x_cord, y_cord, uAction);

    RETURN QUERY SELECT "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P" FROM user_display ORDER BY row_id;
END;
$$;

-- ### FUNCTION: 
-- col_char = stored the character converted x-coord

CREATE OR REPLACE FUNCTION clear_movement() RETURNS VOID AS $$
DECLARE
    x_cord INTEGER := 0;
    y_cord INTEGER := 0;
    col_char VARCHAR(1) := '';
    update_value VARCHAR(40) := '[ - ]';
    bomb_count VARCHAR(1) := ''; 
    uAction VARCHAR(1) := 'N';
    in_flag INTEGER := 0;
BEGIN
    SELECT up.positionY, up.positionX
    INTO y_cord, x_cord
    FROM user_position up
    WHERE up.id = 1;
    
    col_char := CHR(64 + x_cord);

    SELECT uA.action_type
    INTO uAction
    FROM user_action ua
    WHERE ua.id = 1;

    SELECT pt.prev
    INTO update_value
    FROM prev_tile pt
    WHERE pt.row_id = 1;

    EXECUTE format('
        UPDATE user_display ud
        SET %I = $1
        WHERE ud.row_id = $2
    ', col_char) USING update_value, y_cord;
    
    -- if the last action used was M
    IF uAction = 'R' THEN
        EXECUTE format('
            SELECT mf.%I
            FROM minefield mf
            WHERE mf.row_id = $1', col_char)
        INTO bomb_count
        USING y_cord;

        update_value := '[ ' || bomb_count || ' ]';

        EXECUTE format('
            UPDATE user_display ud
            SET %I = $1
            WHERE ud.row_id = $2', col_char)
        USING update_value, y_cord;        
    END IF;

    RAISE NOTICE '%, %, %, HERE IS THE TABLE', bomb_count, uAction, update_value;

    -- handle flags
    IF uAction = 'F' THEN
        SELECT count(*)
        FROM flags f
        WHERE f.positionX = x_cord AND f.positionY = y_cord
        INTO in_flag;

        RAISE NOTICE '%, %, %', update_value, uAction, in_flag;

        IF in_flag = 1 AND update_value = '[ - ]' THEN
            EXECUTE format('
                UPDATE user_display ud
                SET %I = $1
                WHERE ud.row_id = $2
            ', col_char) USING '[ F ]', y_cord;
        END IF;
        IF in_flag = 0 AND update_value = '[ F ]' THEN
            EXECUTE format('
                UPDATE user_display ud
                SET %I = $1
                WHERE ud.row_id = $2
            ', col_char) USING '[ - ]', y_cord;
        END IF;
    END IF;

    UPDATE user_action ua
    SET action_type = 'N'
    WHERE ua.id = 1;
END $$
LANGUAGE plpgsql;
