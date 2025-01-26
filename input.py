# converts user inputs into SQL commands
import psycopg2
conn = psycopg2.connect(database="minesweeper", 
                        host="localhost", 
                        user="postgres", 
                        password="ethoslab", 
                        port="5433")

cursor = conn.cursor()

with open('game.sql', 'r') as file:
    sql_script = file.read()
    
cursor.execute(sql_script)

results = cursor.fetchall()

for row in results:
    print(row)

conn.commit()
conn.close()