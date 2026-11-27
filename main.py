from pathlib import Path

import sqlalchemy as sa
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from database.connection import engine

print("WORKER SYSTEM BACKEND IS RUNNING")

app = FastAPI(title="OSADI Foreign Worker System")

MIGRATIONS_DIR = Path(__file__).parent / "migrations"


def split_sql(text: str) -> list[str]:
    # Drop "--" comment lines first (they may contain ";"), then split into statements.
    lines = [ln for ln in text.splitlines() if not ln.strip().startswith("--")]
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]


@app.on_event("startup")
async def startup():
    # Runs every .sql file in migrations/ in name order.
    # All statements are additive and use IF NOT EXISTS, so re-running is safe.
    async with engine.begin() as conn:
        for sql_file in sorted(MIGRATIONS_DIR.glob("*.sql")):
            for stmt in split_sql(sql_file.read_text()):
                await conn.execute(sa.text(stmt))
            print(f"Applied {sql_file.name}")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    try:
        async with engine.connect() as conn:
            await conn.execute(sa.text("SELECT 1"))
    except Exception:
        raise HTTPException(status_code=503, detail="database unreachable")
    return {"status": "ok", "database": "ok"}
