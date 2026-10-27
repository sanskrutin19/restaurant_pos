import asyncio
import json
from typing import List, Dict, Callable
from pydantic import BaseModel
from sqlalchemy.orm import Session
from datetime import datetime
from backend.models.order import OrderEvent

def _to_json_compatible(data):
    """Recursively convert datetime objects to ISO strings."""
    if isinstance(data, dict):
        return {k: _to_json_compatible(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [_to_json_compatible(i) for i in data]
    elif isinstance(data, datetime):
        return data.isoformat()
    return data

class EventBus:
    """
    Central event bus for publishing domain events.
    Events can be persisted (Event Sourcing) and broadcasted via WebSockets.
    """
    def __init__(self):
        self._subscribers: Dict[str, List[Callable]] = {}

    def subscribe(self, event_type_name: str, callback: Callable):
        """Subscribe to a specific event type."""
        if event_type_name not in self._subscribers:
            self._subscribers[event_type_name] = []
        self._subscribers[event_type_name].append(callback)

    async def publish(self, event: BaseModel, db: Session = None):
        """
        Publish an event to all subscribers and optionally persist it for event sourcing.
        """
        # Convert to dict and ensure all datetimes are ISO strings for JSON serialization
        event_dict = _to_json_compatible(event.model_dump())

        # 1. Persist Event (Event Sourcing)
        if db:
             event_log = OrderEvent(
                 order_id=event_dict.get('order_id'), # None if not present
                 event_type=event.event_type,
                 event_data=event_dict
             )
             db.add(event_log)
             db.commit()

        # 2. Notify internal subscribers (e.g., WebSocket manager, Audit logger)
        event_type_name = event.event_type
        if event_type_name in self._subscribers:
            for callback in self._subscribers[event_type_name]:
                 # Callbacks could be async or sync
                 if asyncio.iscoroutinefunction(callback):
                     await callback(event_dict)
                 else:
                     callback(event_dict)

    def publish_sync(self, event: BaseModel, db: Session = None):
        """
        Publish an event from a synchronous context safely.
        WARNING: Do NOT call this from an async context, as it may block or fail.
        """
        try:
            try:
                loop = asyncio.get_running_loop()
                # If we are here, we are in an async context. We should NOT be calling publish_sync.
                # However, to avoid immediate crash, we create a task.
                print(f"WARNING: publish_sync called from async context for {event.event_type}. Use await publish() instead.")
                loop.create_task(self.publish(event, db))
                return
            except RuntimeError:
                # No running loop, safe to proceed with standard sync publishing
                pass

            # Standard sync publishing logic
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                loop.run_until_complete(self.publish(event, db))
            finally:
                loop.close()
        except Exception as e:
            print(f"Failed to publish event sync: {e}")

# Global event bus instance
event_bus = EventBus()
