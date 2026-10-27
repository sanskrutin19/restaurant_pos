import sys

with open('backend/api/order_router.py', 'r') as f:
    lines = f.readlines()

new_lines = []
found = False
for i, line in enumerate(lines):
    # Match the dangling return at 801 (1-indexed)
    if i == 800 and 'return order' in line:
        found = True
        new_lines.append("\n")
        new_lines.append("@router.get(\"/{order_id}/kot/history\", response_model=List[KOTLogResponse])\n")
        new_lines.append("def get_kot_history(order_id: int, db: Session = Depends(get_db)):\n")
        new_lines.append("    return db.query(KOTLog).filter(KOTLog.order_id == order_id).order_by(KOTLog.version.desc()).all()\n\n")
        new_lines.append("@router.post(\"/{order_id}/kot/cancel\")\n")
        new_lines.append("async def cancel_kot(order_id: int, request: CancelKOTRequest, db: Session = Depends(get_db)):\n")
        new_lines.append("    try:\n")
        new_lines.append("        order = order_service.get_order_by_id(db, order_id)\n")
        new_lines.append("        if not order:\n")
        new_lines.append("            raise HTTPException(status_code=404, detail=\"Order not found\")\n")
        new_lines.append("        admin_user = db.query(User).filter(User.pin == request.pin).first()\n")
        new_lines.append("        if not admin_user:\n")
        new_lines.append("             raise HTTPException(status_code=403, detail=\"Invalid PIN\")\n")
        new_lines.append("        if (admin_user.role or \"\").lower() not in [\"admin\", \"manager\", \"owner\"]:\n")
        new_lines.append("             perms = admin_user.permissions or {}\n")
        new_lines.append("             if not perms.get(\"can_cancel_kot\", False):\n")
        new_lines.append("                  raise HTTPException(status_code=403, detail=\"Insufficient permissions\")\n")
        new_lines.append("        last_version = db.query(func.max(KOTLog.version)).filter(KOTLog.order_id == order_id).scalar() or 0\n")
        new_lines.append("        log = KOTLog(order_id=order_id, version=last_version + 1, action=\"cancelled\", cancelled_by=admin_user.id, cancel_reason=request.reason, table_number=str(order.table_id) if order.table_id else None)\n")
        new_lines.append("        db.add(log)\n")
        new_lines.append("        for item in order.items:\n")
        new_lines.append("            item.status = \"Cancelled\"\n")
        new_lines.append("            item.kot_status = \"cancelled\"\n")
        new_lines.append("        if order.table_id:\n")
        new_lines.append("            table = db.query(Table).filter(Table.id == order.table_id).first()\n")
        new_lines.append("            if table:\n")
        new_lines.append("                 table.status = \"Available\"\n")
        new_lines.append("                 try: await event_bus.publish(TableUpdatedEvent(table_id=table.id, status=\"Available\"))\n")
        new_lines.append("                 except: pass\n")
        new_lines.append("        order.status = \"Cancelled\"\n")
        new_lines.append("        db.commit()\n")
        new_lines.append("        return {\"message\": \"KOT cancelled successfully\"}\n")
        new_lines.append("    except HTTPException: raise\n")
        new_lines.append("    except Exception as e:\n")
        new_lines.append("        db.rollback()\n")
        new_lines.append("        raise HTTPException(status_code=500, detail=str(e))\n\n")
        new_lines.append("@router.get(\"/{order_id}\", response_model=OrderResponse)\n")
        new_lines.append("def read_order(order_id: int, db: Session = Depends(get_db)):\n")
        new_lines.append("    order = order_service.get_order_by_id(db, order_id)\n")
        new_lines.append("    if not order: raise HTTPException(status_code=404, detail=\"Order not found\")\n")
        new_lines.append("    return order\n")
    else:
        new_lines.append(line)

if found:
    with open('backend/api/order_router.py', 'w') as f:
        f.writelines(new_lines)
    print("SUCCESS: Patched order_router.py")
else:
    print("ERROR: Could not find anchor point.")
