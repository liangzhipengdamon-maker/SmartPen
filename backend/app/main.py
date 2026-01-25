"""
SmartPen Backend - FastAPI Main Entry

智笔后端服务 - AI 硬笔书法教学系统
端云协同架构: Python FastAPI + InkSight + PaddleOCR + DTW
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from app.api.characters import router as characters_router
from app.api.scoring import router as scoring_router

# Create FastAPI app
app = FastAPI(
    title="SmartPen API",
    description="AI-powered calligraphy teaching system (智笔 AI书法教学系统)",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(characters_router, prefix="/api", tags=["characters"])
app.include_router(scoring_router, prefix="/api", tags=["scoring"])


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint - API health check"""
    return {
        "message": "SmartPen API - 智笔书法教学系统",
        "version": "0.1.0",
        "status": "healthy",
        "docs": "/docs",
    }


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn

    # Run the server
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,  # Enable auto-reload for development
    )
