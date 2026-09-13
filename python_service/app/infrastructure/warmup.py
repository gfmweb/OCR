from __future__ import annotations

import threading
from typing import Any

STAGE_PROGRESS = {
    "starting_server": 15,
    "loading_models": 55,
    "warmup_inference": 85,
    "ready": 100,
    "error": 0,
}


class WarmupStatus:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.stage = "starting_server"
        self.progress = STAGE_PROGRESS["starting_server"]
        self.error = False

    def set_stage(self, stage: str) -> None:
        with self._lock:
            self.stage = stage
            self.progress = STAGE_PROGRESS.get(stage, self.progress)
            self.error = stage == "error"

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {
                "stage": self.stage,
                "progress": self.progress,
                "error": self.error,
            }
