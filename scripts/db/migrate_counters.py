import sqlite3

conn = sqlite3.connect('restaurant_pos.db')
c = conn.cursor()

try:
    c.execute('DROP TABLE IF EXISTS kitchen_counters')
    c.execute('ALTER TABLE kitchen_stations RENAME TO kitchen_counters')
    print('Renamed kitchen_stations to kitchen_counters')
except Exception as e:
    print('Rename failed or not needed:', e)

try:
    c.execute("ALTER TABLE kitchen_counters ADD COLUMN icon VARCHAR DEFAULT 'store'")
    c.execute("ALTER TABLE kitchen_counters ADD COLUMN color VARCHAR DEFAULT '#000000'")
    c.execute("ALTER TABLE kitchen_counters ADD COLUMN printer_id INTEGER")
    print('Added columns to kitchen_counters')
except Exception as e:
    print('Add cols failed:', e)

try:
    c.execute('ALTER TABLE menu_categories RENAME COLUMN kitchen_station_id TO kitchen_counter_id')
    print('Renamed col in categories')
except Exception as e:
    print('Rename cat col failed:', e)

try:
    c.execute('ALTER TABLE menu_items RENAME COLUMN kitchen_station_id TO kitchen_counter_id')
    print('Renamed col in items')
except Exception as e:
    print('Rename item col failed:', e)

conn.commit()
print('DONE')
