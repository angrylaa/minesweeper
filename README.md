# Minesweeper w/ SQL

I implemented minesweeper with SQL!

## Demo Video

https://github.com/user-attachments/assets/ef827d45-d3e0-4fef-8927-d6c29a6f3bbe

## Usage
**************
### Installation
1. Set up an SQL server:
  a. With Docker -> this requires you have Docker installed.
  ```
  docker run --name minesweeper -d -p 2022:5432 -e POSTGRES_PASSWORD=postgres postgres
  ```
  b. If you set up your own server, you'll have to change the credentials.
2. Install the dependencies required for this:
```
pip install keyboard psycopg2
```
3. Run the program!
```
python input.py
```
### Starting The Game
1. The starting position of your cursor will ALWAYS be zero.
2. Your cursor is represented by ★

### Keybinds
1. WASD -> This is how you navigate the field.
2. F -> This will flag a cell in the field. You can toggle a flag on/off.
3. R -> This will reveal a cell, OR perform chording.
  a. Chording will cause the game to end IF you accidentally reveal a mine.
