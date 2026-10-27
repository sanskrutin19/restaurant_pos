-- Migration: Add name column to order_items table
-- This stores the item name at the time of order for historical accuracy

-- For SQLite:
ALTER TABLE order_items ADD COLUMN name TEXT;

-- Update existing order items with their menu item names
-- (This will only work if the menu items still exist)
UPDATE order_items 
SET name = (
    SELECT name 
    FROM menu_items 
    WHERE menu_items.id = order_items.item_id
)
WHERE name IS NULL;
