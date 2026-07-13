import uvicorn

if __name__ == "__main__":
    print("🚀 Starting SecureWatch Backend...")
    print("📖 API Docs: http://localhost:8000/docs")
    print("=" * 50)

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )