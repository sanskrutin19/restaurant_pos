import json
from typing import List
from fastapi import WebSocket

class ConnectionManager:
    """
    Manages active WebSocket connections for real-time updates (KDS, POS terminals).
    """
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        """Broadcasts a message to all connected clients."""
        msg_str = json.dumps(message)
        # Use a copy of the list to avoid RuntimeError if connections are removed during iteration
        for connection in list(self.active_connections):
            # NEW: Run each send in a background task so one slow client doesn't block the login/order flow
            import asyncio
            asyncio.create_task(self._safe_send_text(connection, msg_str))

    async def _safe_send_text(self, websocket: WebSocket, message: str):
        """Helper to send text and handle disconnects if the socket is dead."""
        try:
            await websocket.send_text(message)
        except Exception as e:
            print(f"WS Broadcast Error: {e}")
            self.disconnect(websocket)

manager = ConnectionManager()

async def ws_event_publisher(event_data: dict):
    """
    Bridge function to link EventBus with the WebSocket ConnectionManager.
    Sends flat event dict with event_type at root level so frontend can
    read data['event_type'] directly.
    """
    print(f"WS Broadcasting Event: {event_data.get('event_type')}")
    await manager.broadcast(event_data)

# Register the WebSocket broadcaster to all relevant events
# We can do this explicitly for each event type or lazily.
# Let's say we subscribe to important ones:
from backend.events.core import event_bus
from backend.schemas.events import (
    OrderCreatedEvent, ItemAddedEvent, OrderSentToKitchenEvent, 
    OrderReadyEvent, PaymentCompletedEvent, TableUpdatedEvent, LowStockEvent
)

event_bus.subscribe("order_created", ws_event_publisher)
event_bus.subscribe("order_status_updated", ws_event_publisher)
event_bus.subscribe(ItemAddedEvent.model_fields['event_type'].default, ws_event_publisher)
event_bus.subscribe(OrderSentToKitchenEvent.model_fields['event_type'].default, ws_event_publisher)
event_bus.subscribe(OrderReadyEvent.model_fields['event_type'].default, ws_event_publisher)
event_bus.subscribe(PaymentCompletedEvent.model_fields['event_type'].default, ws_event_publisher)
event_bus.subscribe(TableUpdatedEvent.model_fields['event_type'].default, ws_event_publisher)
event_bus.subscribe(LowStockEvent.model_fields['event_type'].default, ws_event_publisher)
