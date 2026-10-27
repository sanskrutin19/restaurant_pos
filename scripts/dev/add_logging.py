import sys

with open('backend/api/order_router.py', 'r') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    # Find the line with CRITICAL ERROR print
    if 'CRITICAL ERROR in cancel_kot' in line:
        # Before the raise, write error to a file
        new_lines.append("        with open('error_log.txt', 'a') as ef:\n")
        new_lines.append("            ef.write(f\"\\nERROR: {str(e)}\\n\")\n")
        new_lines.append("            traceback.print_exc(file=ef)\n")
    new_lines.append(line)

with open('backend/api/order_router.py', 'w') as f:
    f.writelines(new_lines)
