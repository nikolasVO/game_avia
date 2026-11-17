import argparse
import asyncio
import fcntl
import os
import signal
import time
from pathlib import Path
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store
from integrations.telegram.bot import Telegram

async def main():
    load_environment(role="coordinator")
    p=state_dir()
    lock=open(p/"runtime.lock","a")
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    store=Store(p/"coordinator.sqlite3")
    store.recover()
    store.kv("budget_status","budget_not_configured; bootstrap cap: 12 text requests, 1 image request; large autonomous backlog disabled.")
    # Coordinator persists tasks immediately; executor only accepts explicitly enabled bounded jobs.
    await Telegram(store).run()

if __name__=="__main__":asyncio.run(main())

