import sqlite3
db=sqlite3.connect('restaurant_pos.db')
columns = db.execute("PRAGMA table_info('menu_items')").fetchall()
for c in columns:
    print(c[1], c[2])
