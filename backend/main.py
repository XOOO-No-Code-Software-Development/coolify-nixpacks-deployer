from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Literal, Any, Dict
from datetime import datetime

app = FastAPI(
    title="Backend template",
    version="1.0.0",
    description="API for managing backend"
)

# CORS configuration to allow frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class DatabaseQueryRequest(BaseModel):
    query: str
    params: Optional[List[Any]] = []

@app.get("/", tags=["health"])
async def root():
    """Health check endpoint"""
    return {
        "status": "ok",
        "message": "Backend is running",
        "version": "1.0.0"
    }

@app.get("/health", tags=["health"])
async def health():
    """Health check endpoint for monitoring"""
    return {
        "status": "ok",
        "message": "Backend is healthy",
        "version": "1.0.0"
    }