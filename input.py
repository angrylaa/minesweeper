# converts user inputs into SQL commands
import psycopg2
import keyboard
import os

def clear_terminal():
    os.system('cls' if os.name == 'nt' else 'clear')

conn = psycopg2.connect(database="minesweeper", 
                        host="localhost", 
                        user="postgres", 
                        password="ethoslab", 
                        port="5433")

cursor = conn.cursor()

# setup game board
with open('setup.sql', 'r') as file:
    sql_script = file.read()
    
cursor.execute(sql_script)

# for row in results:
#     print(row)

action_map = {
    'w': 'SELECT move_up()',
    'a': "SELECT move_left()",
    's': "SELECT move_down()",
    'd': "SELECT move_right()",
    'f': "SELECT flag()",
    'r': "SELECT mark()",
}

def execute_action(action):
    if action.lower() in action_map:
        try:
            cursor.execute(action_map[action])
            conn.commit()
        except Exception as e:
            print(e)

print("Enter movement keys (WASD) to move your icon -> ★ \nActions -> (R to reveal a spot / F to flag a spot).")

# print initial state
cursor.execute("SELECT display_state()")
for record in cursor:
    cleaned_line = record[0].translate({ord(c): None for c in ',()"'})
    print(cleaned_line.replace("F", "⚑").replace("X","★").replace("-"," "))
cursor.execute("SELECT clear_movement()")


# game loop
while True:
    event = keyboard.read_event()

    if event.event_type == keyboard.KEY_DOWN:
        key = event.name
        if key == "q":
            break
        execute_action(key)
        conn.commit()

        cursor.execute("SELECT display_state()")
        clear_terminal()
        for record in cursor:
            cleaned_line = record[0].translate({ord(c): None for c in ',()"'})
            print(cleaned_line.replace("F", "⚑").replace("X", "★").replace("-"," ").replace(" M ", "💣 "))

        cursor.execute("SELECT clear_movement()")

conn.close()