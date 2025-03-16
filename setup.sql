CREATE OR REPLACE FUNCTION notify(str varchar) RETURNS void AS $$
BEGIN
    RAISE NOTICE '%', str;
END
$$ LANGUAGE PLPGSQL;

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
CREATE TABLE IF NOT EXISTS mine_table(
    mine_id INTEGER,
    x INTEGER,
    y INTEGER
);

INSERT INTO minefield("A") VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0), (0);

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

INSERT INTO user_display("A") VALUES ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]'), ('[ - ]');

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
            y_cord = floor(random() * 16) + 1;
            x_cord = floor(random() * 16) + 1;

            EXECUTE format('
                SELECT COUNT(*)
                FROM mine_table mt
                WHERE mt.x = $1 AND mt.y = $2
            ')
            INTO duplicate
            USING x_cord, y_cord; 

            IF duplicate = 0 THEN
                INSERT INTO mine_table (mine_id, x, y)
                VALUES(total_bombs, x_cord, y_cord);

                total_bombs = total_bombs + 1;
            END IF;
        END LOOP;
    END;
$$;

SELECT * FROM generate_mines();

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

            col_char := CHR(64 + x_cord);

            EXECUTE format('
                UPDATE minefield mf
                SET %I = $1
                WHERE mf.row_id = $2
            ', col_char) USING 'M', y_cord;
        END LOOP;
    END;
    $$;

SELECT * FROM insert_bombs();

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
                IF col_num = 1 AND j = -1 OR col_num = 16 AND j = 1 OR row_num = 1 AND i = -1 OR row_num = 16 AND i = 1 THEN
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
                UPDATE minefield mf
                SET %I = $1
                WHERE mf.row_id = $2 AND mf.%I != $3', 
                col_char, col_char) USING adj_bombs, r, 'M';
            END LOOP;
        END LOOP;
    END;
$$;

SELECT initial_count();

-- SETUP FOR PLAYER INPUT

DROP TABLE IF EXISTS user_position;
CREATE TABLE IF NOT EXISTS user_position(
    id SERIAL PRIMARY KEY,
    positionX INTEGER NOT NULL,
    positionY INTEGER NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS user_action;
CREATE TABLE IF NOT EXISTS user_action(
    id SERIAL PRIMARY KEY,
    positionX INTEGER NOT NULL,
    positionY INTEGER NOT NULL,
    action_type VARCHAR(40) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- need to find first available 0!
CREATE OR REPLACE FUNCTION startingPoint()
    RETURNS VOID AS $$
    DECLARE 
        col_char VARCHAR(1) := '';
        bomb_count VARCHAR(1) := 0;
    BEGIN
        FOR colIterate IN 1..16 LOOP
            FOR rowIterate IN 1..16 LOOP

                col_char := CHR(64 + colIterate);
        
                EXECUTE format('
                    SELECT mf.%I
                    FROM minefield mf
                    WHERE row_id = $1', col_char)
                INTO bomb_count
                USING rowIterate;


                -- TODO: gotta fix this, keeps erroring and saying no destination & does not insert properly into user position

                IF bomb_count = '0' THEN
                    SELECT notify(format('%s, %s, %s', bomb_count, colIterate, rowIterate));
                    INSERT INTO user_position (positionX, positionY) VALUES (colIterate, rowIterate);
                    EXIT;
                END IF;
            END LOOP;
        END LOOP;
    END
$$ LANGUAGE plpgsql;

INSERT INTO user_action (positionX, positionY, action_type) VALUES (0,0,'N');

CREATE OR REPLACE FUNCTION move_up() RETURNS VOID AS $$
BEGIN
    UPDATE user_position
    SET positionX = positionX - 1
    WHERE id = 1 AND positionX != 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION move_down() RETURNS VOID AS $$
BEGIN
    UPDATE user_position
    SET positionX = positionX + 1
    WHERE id = 1 AND positionX != 16;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION move_left() RETURNS VOID AS $$
BEGIN
    UPDATE user_position
    SET positionY = positionY - 1
    WHERE id = 1 AND positionY != 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION move_right() RETURNS VOID AS $$
BEGIN
    UPDATE user_position
    SET positionY = positionY + 1
    WHERE id = 1 AND positionY != 16;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION flag() RETURNS VOID AS $$
DECLARE
    uCol INTEGER := 0;
    uRow INTEGER := 0;
BEGIN
    SELECT up.positionX, up.positionY
    INTO uRow, uCol
    FROM user_position up
    WHERE up.id = 1;

    UPDATE user_action
    SET positionX = uRow, positionY = uCol, action_type = 'F'
    WHERE id = 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark() RETURNS VOID AS $$
DECLARE
    uCol INTEGER := 0;
    uRow INTEGER := 0;
BEGIN
    SELECT up.positionX, up.positionY
    INTO uRow, uCol
    FROM user_position up
    WHERE up.id = 1;

    UPDATE user_action
    SET positionX = uRow, positionY = uCol, action_type = 'M'
    WHERE id = 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION enter_action(uCol int, uRow int, uAct char) RETURNS VOID AS $$
DECLARE
    col_char VARCHAR(1) := '';
    current_value VARCHAR(1) := '';
BEGIN
    col_char := CHR(64 + uCol);

    EXECUTE format('
        SELECT mf.%I
        FROM minefield mf
        WHERE row_id = $1',
        col_char) USING uRow;
    
END;
$$ LANGUAGE plpgsql;

-- BOARD DISPLAY

-- function needs to parse all available information & latest state of map (minefield)
-- 1. user position & user action
-- 2. map state
-- THEN:
-- very first user selection -> zero-open -> this is how to start the game (if a revealed cell is zero, reveal all its neighbours)
-- a 4 way flood -> how to determine WHEN EXISTS to show users tiles

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
    uCol INTEGER := 0;
    uRow INTEGER := 0;
    col_char VARCHAR(1) := '';
    uAction VARCHAR(10) := '';
BEGIN
    SELECT up.positionX, up.positionY
    INTO uRow, uCol
    FROM user_position up
    WHERE up.id = 1;

    SELECT uA.action_type
    INTO uAction
    FROM user_action ua
    WHERE ua.id = 1;
    
    col_char := CHR(64 + uCol);

    EXECUTE format('
        UPDATE user_display ud
        SET %I = $1
        WHERE ud.row_id = $2
    ', col_char) USING '[ X ]', uRow;

    PERFORM enter_action(uCol, uRow, uAction);

    RETURN QUERY SELECT "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P" FROM user_display ORDER BY row_id;
END;
$$;

CREATE OR REPLACE FUNCTION clear_movement() RETURNS VOID AS $$
DECLARE
    uCol INTEGER := 0;
    uRow INTEGER := 0;
    col_char VARCHAR(1) := '';
BEGIN
    SELECT up.positionX, up.positionY
    INTO uRow, uCol
    FROM user_position up
    WHERE up.id = 1;
    
    col_char := CHR(64 + uCol);

    EXECUTE format('
        UPDATE user_display ud
        SET %I = $1
        WHERE ud.row_id = $2
    ', col_char) USING '[ - ]', uRow;
END $$
LANGUAGE plpgsql;
