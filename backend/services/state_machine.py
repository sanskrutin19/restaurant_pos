from typing import List, Dict

class InvalidStateTransitionError(Exception):
    pass

class OrderStateMachine:
    """
    Enforces a strict lifecycle for Orders.
    Valid states: Created -> Preparing -> Ready -> Served -> Paid
    """
    
    STATES = ["Pending", "Preparing", "Ready", "Served", "Paid", "Cancelled", "Held"]
    
    # Define valid transitions FROM a state TO a list of allowed states
    _transitions: Dict[str, List[str]] = {
        "Pending": ["Preparing", "Cancelled", "Held"],
        "Preparing": ["Ready", "Cancelled"],
        "Ready": ["Served", "Cancelled"],
        "Served": ["Paid"],
        "Paid": [],  # Terminal state
        "Cancelled": [],  # Terminal state
        "Held": ["Pending", "Cancelled", "Preparing"],
    }

    @classmethod
    def validate_transition(cls, current_state: str, new_state: str):
        # Normalize to Title Case for comparison
        curr = current_state.title()
        new_s = new_state.title()
        
        # Special case mapping for legacy or alternative names if needed
        # e.g. "Created" -> "Pending"
        if curr == "Created": curr = "Pending"
        
        if curr not in cls.STATES:
            raise InvalidStateTransitionError(f"Unknown current state: {current_state}")
        if new_s not in cls.STATES:
             raise InvalidStateTransitionError(f"Unknown new state: {new_state}")
             
        allowed_next_states = cls._transitions.get(curr, [])
        if new_s not in allowed_next_states:
            raise InvalidStateTransitionError(
                f"Invalid transition from '{curr}' to '{new_s}'. "
                f"Allowed next states are: {allowed_next_states}"
            )

    @classmethod
    def transition(cls, command_payload, new_state: str):
        pass
        # This could be used to wrap the actual model update
