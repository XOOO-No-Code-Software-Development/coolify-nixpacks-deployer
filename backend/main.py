from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Literal, Any, Dict
from datetime import datetime
import uuid
import os
import psycopg2
import psycopg2.extras
import json

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

@app.post("/database/query", tags=["database"])
async def execute_query(request: DatabaseQueryRequest):
    """Execute a database query and return results"""
    database_url = os.getenv("DATABASE_URL")
    
    if not database_url:
        raise HTTPException(status_code=500, detail="DATABASE_URL not configured")
    
    try:
        # Connect to database
        conn = psycopg2.connect(database_url)
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        # Execute query
        cursor.execute(request.query, request.params)
        
        # Fetch results if it's a SELECT query
        if request.query.strip().upper().startswith('SELECT'):
            rows = cursor.fetchall()
            
            # Convert RealDictRow to regular dict and handle special types
            result_rows = []
            for row in rows:
                result_row = {}
                for key, value in row.items():
                    # Convert datetime objects to ISO format strings
                    if isinstance(value, datetime):
                        result_row[key] = value.isoformat()
                    else:
                        result_row[key] = value
                result_rows.append(result_row)
            
            # Get column information
            columns = [
                {
                    "name": desc[0],
                    "type_code": desc[1]
                }
                for desc in cursor.description
            ] if cursor.description else []
            
            result = {
                "success": True,
                "rows": result_rows,
                "rowCount": len(result_rows),
                "columns": columns
            }
        else:
            # For non-SELECT queries (INSERT, UPDATE, DELETE, etc.)
            conn.commit()
            result = {
                "success": True,
                "rows": [],
                "rowCount": cursor.rowcount,
                "columns": []
            }
        
        cursor.close()
        conn.close()
        
        return result
        
    except psycopg2.Error as e:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "Query execution failed",
                "message": str(e),
                "code": e.pgcode if hasattr(e, 'pgcode') else None
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail={"error": "Internal server error", "message": str(e)}
        )
