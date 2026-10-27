import os

file_path = 'backend/api/order_router.py'
if os.path.exists(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Truncate to 751 lines (index 0 to 750)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(lines[:751])
    print(f"Truncated {file_path} to 751 lines.")
else:
    print(f"File {file_path} not found.")
