from typing import Callable, Dict, Type
from pydantic import BaseModel
from sqlalchemy.orm import Session

class CommandBus:
    """
    Central command bus for resolving and dispatching commands to their appropriate handlers.
    In a CQRS architecture, the command bus ensures that each command is handled by exactly one handler.
    """
    def __init__(self):
        self._handlers: Dict[Type[BaseModel], Callable] = {}

    def register(self, command_type: Type[BaseModel], handler: Callable):
        """Registers a handler for a specific command type."""
        if command_type in self._handlers:
            raise ValueError(f"Command {command_type.__name__} already has a registered handler.")
        self._handlers[command_type] = handler

    async def dispatch(self, command: BaseModel, db: Session):
        """Dispatches a command to its registered handler."""
        handler = self._handlers.get(type(command))
        if not handler:
            raise ValueError(f"No handler registered for command {type(command).__name__}")
        
        # Handlers are expected to take the command and the database session
        import asyncio
        if asyncio.iscoroutinefunction(handler):
            return await handler(command, db)
        return handler(command, db)

# Global command bus instance
command_bus = CommandBus()
