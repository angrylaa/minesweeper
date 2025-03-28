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

-- contains all 40 mines & their cords
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

-- tracks how many tiles are revealed
DROP TABLE IF EXISTS revealed;
CREATE TABLE IF NOT EXISTS revealed(
    id SERIAL PRIMARY KEY,
    revealedTiles INTEGER NOT NULL
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
-- x_cord = stores the x-cordinate
-- y_cord = stores the y-cordinate
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

            -- selects the number of rows (0 or 1) that have the same cords
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
-- col_char = stored the character converted x-cord
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
-- total_current_cell_value = stores the number of bombs near cell
-- col_char = stored the character converted x-cord
-- is_bomb = flag on whether the cell contains a bomb

CREATE OR REPLACE FUNCTION count_adjacent_bombs(x_cord int, y_cord int)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    total_current_cell_value INTEGER := 0;
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
                    
                    -- add bombs to the total_current_cell_value
                    total_current_cell_value := total_current_cell_value + is_bomb;
                END IF;
            END IF;
        END LOOP;
    END LOOP;

    -- returns the total_current_cell_valued
    RETURN total_current_cell_value;
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
-- current_cell_value = stores the bomb count of a cell
-- x_cord = tracks the x_cord
-- y_cord = tracks the y_cord

CREATE OR REPLACE FUNCTION startingPoint()
    RETURNS VOID AS $$
    DECLARE 
        col_char VARCHAR(1) := '';
        current_cell_value VARCHAR(1) := 0;
        x_cord INTEGER := 1;
        y_cord INTEGER := 1;
    BEGIN
        LOOP
            LOOP
                -- convert the x_cord into a character
                col_char := CHR(64 + x_cord);
        
                -- find the current_cell_value of the current cell
                -- starts at (1,1)
                EXECUTE format('
                    SELECT mf.%I
                    FROM minefield mf
                    WHERE row_id = $1', col_char)
                INTO current_cell_value
                USING y_cord;

                -- if the current_cell_value is 0
                IF current_cell_value = '0' THEN
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
-- current_cell_value = tracks what the value in a cell is
-- in_flag = tracks which flags have been placed
-- update_value = tracks the current user-display value

CREATE OR REPLACE FUNCTION enter_action(x_cord int, y_cord int, uAct char) RETURNS VOID AS $$
DECLARE
    col_char VARCHAR(1) := '';
    current_cell_value VARCHAR(1) := '';
    in_flag INTEGER := 0;
    user_display_value VARCHAR(40) := '[ - ]';
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

    -- check if the current cell has a record in the flag table
    -- output: 0 → this cell has not been flagged
    -- output: 1  → this cell has been flagged
    SELECT count(*)
    FROM flags f
    WHERE f.positionX = x_cord AND f.positionY = y_cord
    INTO in_flag;

    -- find the previous value of the current cell before it's updated with X
    SELECT pt.prev
    INTO user_display_value
    FROM prev_tile pt
    WHERE pt.row_id = 1;

    -- toggle flag
    -- the user presses the F key
    IF uAct = 'F' THEN
        -- if the flag is not currently flagged
        -- if the current displayed value is [ - ] = prevents flagging numbers
        IF in_flag = 0 AND user_display_value = '[ - ]' THEN
            -- add the flag into the tracker
            INSERT INTO flags(positionX, positionY) VALUES(x_cord, y_cord);
        END IF;

        -- if the flag is currently flagged
        IF in_flag = 1 THEN
            -- remove the flag from the tracker
            DELETE FROM flags WHERE positionX = x_cord AND positionY = y_cord;
        END IF;
    END IF;

    -- if the user presses the R key
    IF uAct = 'R' THEN
        -- ## OPEN TO THE GAME
        -- if the cell contains 0 mines &  user tries to reveal
        IF current_cell_value = '0' THEN
            -- zero open & reveal nearest neighbour
            PERFORM zero_open(x_cord, y_cord);
        ELSE 
            -- ## USER REVEALS A MINE
            -- if current cell contains a mine & user tries to reveal
            IF current_cell_value = 'M' THEN
                -- set action to 'L' which initiates the end
                UPDATE user_action
                SET action_type = 'L'
                WHERE id = 1;
            
            -- ## chording
            -- if the user display is empty / not revealed (aka pressing R on any revealed cell)
            ELSIF user_display_value != '[ - ]' THEN
                -- perform chording
                PERFORM chording(x_cord, y_cord);
            END IF;
        END IF;
    END IF;

    -- AFTER ALL ACTIONS ARE COMPLETE:
    -- we update the user_display to show the marker
    EXECUTE format('
        UPDATE user_display ud
        SET %I = $1
        WHERE ud.row_id = $2
    ', col_char) USING '[ X ]', y_cord;
END;
$$ LANGUAGE plpgsql;

-- ### FUNCTION: chording function
-- col_char = stored the character converted x-cord
-- current_cell_value = 
-- user_display_value =
-- update_value = 
CREATE OR REPLACE FUNCTION chording(x_cord int, y_cord int) RETURNS VOID AS $$
DECLARE
    col_char VARCHAR(1) := '';
    current_cell_value VARCHAR(1) := '';
    user_display_value VARCHAR(10) := '';
    update_value VARCHAR(40) := '[ - ]';
BEGIN
    FOR i IN -1..1 LOOP -- check from top left
        FOR j IN -1..1 LOOP -- to bottom right
            IF i = 0 AND j = 0 THEN  -- skip the center cell
            ELSE
                -- skip out of bound indexes
                IF x_cord = 1 AND j = -1 OR x_cord = 16 AND j = 1 OR y_cord = 1 AND i = -1 OR y_cord = 16 AND i = 1 THEN
                ELSE
                    -- convert the x_cord into a character
                    col_char := CHR(64 + x_cord + j);

                    -- find the current cell value in the cell
                    EXECUTE format('
                        SELECT mf.%I
                        FROM minefield mf
                        WHERE mf.row_id = $1', col_char)
                    INTO current_cell_value
                    USING y_cord + i;

                    -- find the current value in the user_display for that cell
                    EXECUTE format('
                        SELECT %I
                        FROM user_display ud
                        WHERE row_id = $1
                    ', col_char)
                    INTO user_display_value
                    USING y_cord + i;

                    -- if the cell is a bomb & it wasn't revealed (aka [ - ] value in user display)
                    IF current_cell_value = 'M' AND user_display_value = '[ - ]' THEN
                        -- user loses the game
                        UPDATE user_action
                        SET action_type = 'L'
                        WHERE id = 1;
                    
                    -- if the cell is equal to 0, then we need to perform a zero-open
                    ELSIF current_cell_value = '0' THEN
                        PERFORM zero_open(x_cord, y_cord);
                    ELSE
                    -- otherwise, reveal all cells around the selected cell
                        EXECUTE format('
                            SELECT mf.%I
                            FROM minefield mf
                            WHERE mf.row_id = $1', col_char)
                        INTO current_cell_value
                        USING y_cord + i;

                        IF current_cell_value = 'M' THEN
                            update_value := '[ F ]';
                        ELSE
                            update_value := '[ ' || current_cell_value || ' ]';
                        END IF;

                        EXECUTE format('
                            UPDATE user_display ud
                            SET %I = $1
                            WHERE ud.row_id = $2', col_char)
                        USING update_value, y_cord + i;     
                    END IF;
                END IF;
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ### FUNCTION: this function opens all surrounding cells when a 0 is revealed
-- col_char = stored the character converted x-cord
-- current_cell_value = tracks the value stored in the current cell
-- is_visited = tracks which cells have been visited
-- update_value = contains the value to be updated

CREATE OR REPLACE FUNCTION zero_open(x_cord int, y_cord int) RETURNS VOID AS $$
DECLARE
    col_char VARCHAR(1) := '';
    current_cell_value VARCHAR(1) := '';
    is_visited INTEGER := 0;
    update_value VARCHAR(40) := '[ - ]';
BEGIN
    FOR i IN -1..1 LOOP -- check from top left
        FOR j IN -1..1 LOOP -- to bottom right
            IF i = 0 AND j = 0 THEN  -- skip the center cell
            ELSE
                -- skip out of bound indexes
                IF x_cord = 1 AND j = -1 OR x_cord = 16 AND j = 1 OR y_cord = 1 AND i = -1 OR y_cord = 16 AND i = 1 THEN
                ELSE
                    -- convert the x_cord into a character
                    col_char := CHR(64 + x_cord + j);

                    -- find the current cell value in the cell
                    EXECUTE format('
                        SELECT mf.%I
                        FROM minefield mf
                        WHERE mf.row_id = $1', col_char)
                    INTO current_cell_value
                    USING y_cord + i;

                    -- update the user_display based on the value 
                    update_value := '[ ' || current_cell_value || ' ]';

                    EXECUTE format('
                        UPDATE user_display ud
                        SET %I = $1
                        WHERE ud.row_id = $2', col_char)
                    USING update_value, y_cord + i;

                    -- updates which cells have been visited
                    -- this prevents the recursion from being endless
                    SELECT count(*)
                    FROM visited v
                    WHERE v.positionX = x_cord + j AND v.positionY = y_cord + i
                    INTO is_visited;

                    -- if this cell hasn't been visited yet
                    IF is_visited = 0 THEN
                        -- insert it into the visited table
                        EXECUTE format('
                            INSERT INTO visited(positionX, positionY)
                            VALUES ($1, $2)
                        ')
                        USING x_cord + j, y_cord + i;

                        -- only recursive function IF the user display is [ - ] AKA unrevealed
                        IF current_cell_value = '0' THEN
                            PERFORM zero_open(x_cord + j, y_cord + i);
                        END IF;
                    END IF;
                END IF;
            END IF;
        END LOOP;
    END LOOP;

    -- get the number of cells have been visited 
    SELECT count(*)
    FROM visited v
    INTO is_visited;

    -- update the number of revealed cells with the visited cells
    UPDATE revealed r
    SET revealedTiles = revealedTiles + is_visited
    WHERE r.id = 1;
END;
$$ LANGUAGE plpgsql;

-- ### FUNCTION: 
-- col_char = stored the character converted x-cord
-- x_cord = gets the current x-cord of the user
-- y_cord = gets the current y-cord of the user
-- uAction = gets the current action from the user
-- user_display_value = 

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
    user_display_value VARCHAR(10) := '';
BEGIN
    -- get the user position
    SELECT up.positionY, up.positionX
    INTO y_cord, x_cord
    FROM user_position up
    WHERE up.id = 1;

    -- get the user action
    SELECT uA.action_type
    INTO uAction
    FROM user_action ua
    WHERE ua.id = 1;

    -- convert the x-cord into the a character
    col_char := CHR(64 + x_cord);

    -- find the current value of the user display cell
    EXECUTE format('
        SELECT %I
        FROM user_display ud
        WHERE row_id = $1
    ', col_char)
    INTO user_display_value
    USING y_cord;

    -- store the value of the user display for the current cell
    -- this'll be used for state management
    UPDATE prev_tile pt
    SET prev = user_display_value
    WHERE pt.row_id = 1;

    -- perform the user action
    PERFORM enter_action(x_cord, y_cord, uAction);

    -- get the user action from the table
    SELECT uA.action_type
    INTO uAction
    FROM user_action ua
    WHERE ua.id = 1;

    -- if the action is L, then the game is over
    IF uAction = 'L' THEN
        RAISE NOTICE 'game over';
        RETURN QUERY SELECT
            'G'::VARCHAR(40) AS "A",
            'A'::VARCHAR(40) AS "B",
            'M'::VARCHAR(40) AS "C",
            'E'::VARCHAR(40) AS "D",
            '-'::VARCHAR(40) AS "E",
            'O'::VARCHAR(40) AS "F",
            'V'::VARCHAR(40) AS "G",
            'E'::VARCHAR(40) AS "H",
            'R'::VARCHAR(40) AS "I",
            '-'::VARCHAR(40) AS "J",
            '-'::VARCHAR(40) AS "K",
            '-'::VARCHAR(40) AS "L",
            '-'::VARCHAR(40) AS "M",
            '-'::VARCHAR(40) AS "N",
            '-'::VARCHAR(40) AS "O",
            '-'::VARCHAR(40) AS "P";
    ELSE
        -- otherwise return the user_display
        RETURN QUERY SELECT "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P" 
        FROM user_display
        ORDER BY row_id;
    END IF;
END;
$$;

-- ### FUNCTION: 
-- x_cord = stores the user x-cord
-- y_cord = stores the user y-cord
-- col_char = stores the character converted x-cord
-- update_value = 
-- current_cell_value = gets the current value from the user_display
-- uAction = get the current user action
-- in_flag = checks if the current cell is flagged
CREATE OR REPLACE FUNCTION clear_movement() RETURNS VOID AS $$
DECLARE
    x_cord INTEGER := 0;
    y_cord INTEGER := 0;
    col_char VARCHAR(1) := '';
    display_cell_value VARCHAR(40) := '[ - ]';
    current_cell_value VARCHAR(1) := ''; 
    uAction VARCHAR(1) := 'N';
    in_flag INTEGER := 0;
BEGIN
    -- get the user position
    SELECT up.positionY, up.positionX
    INTO y_cord, x_cord
    FROM user_position up
    WHERE up.id = 1;
    
    -- convert the x-cord into a character
    col_char := CHR(64 + x_cord);

    -- get the current user action
    SELECT uA.action_type
    INTO uAction
    FROM user_action ua
    WHERE ua.id = 1;

    -- get the value of the user display for the current cell
    SELECT pt.prev
    INTO display_cell_value
    FROM prev_tile pt
    WHERE pt.row_id = 1;

    -- update the user display with the value of the user_display for the cell
    -- this is needed because otherwise X would leave the cell blank
    EXECUTE format('
        UPDATE user_display ud
        SET %I = $1
        WHERE ud.row_id = $2
    ', col_char) USING display_cell_value, y_cord;
    
    -- if the last action used was R
    IF uAction = 'R' THEN
        -- then get the value of the current cell
        EXECUTE format('
            SELECT mf.%I
            FROM minefield mf
            WHERE mf.row_id = $1', col_char)
        INTO current_cell_value
        USING y_cord;

        -- replace the display cell value with the current bomb count
        display_cell_value := '[ ' || current_cell_value || ' ]';

        -- update the user display with the current bomb count
        EXECUTE format('
            UPDATE user_display ud
            SET %I = $1
            WHERE ud.row_id = $2', col_char)
        USING display_cell_value, y_cord;     

        -- update the revealed cells + 1
        UPDATE revealed r
        SET revealedTiles = revealedTiles + 1
        WHERE r.id = 1;
    END IF;

    -- if the last action used was R
    IF uAction = 'F' THEN
        -- find whether the current cell is flagged / exists in flag table
        SELECT count(*)
        FROM flags f
        WHERE f.positionX = x_cord AND f.positionY = y_cord
        INTO in_flag;

        -- if the flag does exist & the current cell is not revealed / unopened
        IF in_flag = 1 AND current_cell_value = '[ - ]' THEN
            -- set the current cell to be flagged (user toggles)
            EXECUTE format('
                UPDATE user_display ud
                SET %I = $1
                WHERE ud.row_id = $2
            ', col_char) USING '[ F ]', y_cord;
        END IF;
        -- if the flag doesn't exist & the current cell is flagged
        IF in_flag = 0 AND current_cell_value = '[ F ]' THEN
            -- set the current cell to be unrevealed (user untoggles)
            EXECUTE format('
                UPDATE user_display ud
                SET %I = $1
                WHERE ud.row_id = $2
            ', col_char) USING '[ - ]', y_cord;
        END IF;
    END IF;

    -- reset the user action
    UPDATE user_action ua
    SET action_type = 'N'
    WHERE ua.id = 1;
END $$
LANGUAGE plpgsql;
