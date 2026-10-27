import sqlite3
db=sqlite3.connect('restaurant_pos.db')
tables=[r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
for t in tables:
    print(t)
