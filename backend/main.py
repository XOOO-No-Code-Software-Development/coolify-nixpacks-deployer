from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Literal
from datetime import datetime
import uuid

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

@app.get("/", tags=["health"])
async def root():
    """Health check endpoint"""
    return {
        "status": "ok",
        "message": "Todo App API is running",
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
