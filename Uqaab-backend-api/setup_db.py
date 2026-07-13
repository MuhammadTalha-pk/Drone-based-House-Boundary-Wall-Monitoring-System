# """
# Run this ONCE to create the database.
# """
# import psycopg2
# from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
# from app.core.config import settings


# def create_database():
#     print("🔄 Connecting to PostgreSQL...")

#     try:
#         # Connect to PostgreSQL (without specifying a database)
#         conn = psycopg2.connect(
#             host=settings.DB_HOST,
#             port=settings.DB_PORT,
#             user=settings.DB_USER,
#             password=settings.DB_PASSWORD,
#         )
#         conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
#         cursor = conn.cursor()

#         # Check if database exists
#         cursor.execute(
#             f"SELECT 1 FROM pg_database WHERE datname = '{settings.DB_NAME}'"
#         )
#         exists = cursor.fetchone()

#         if not exists:
#             cursor.execute(f"CREATE DATABASE {settings.DB_NAME}")
#             print(f"✅ Database '{settings.DB_NAME}' created!")
#         else:
#             print(f"✅ Database '{settings.DB_NAME}' already exists!")

#         cursor.close()
#         conn.close()

#     except Exception as e:
#         print(f"❌ Error: {e}")
#         print("")
#         print("Make sure:")
#         print("  1. PostgreSQL is installed and running")
#         print("  2. Username and password in .env are correct")
#         print("  3. Try opening pgAdmin to verify PostgreSQL is working")
#         return False

#     return True


# if __name__ == "__main__":
#     print("=" * 50)
#     print("  SecureWatch Database Setup")
#     print("=" * 50)
#     print(f"  Host: {settings.DB_HOST}:{settings.DB_PORT}")
#     print(f"  User: {settings.DB_USER}")
#     print(f"  Database: {settings.DB_NAME}")
#     print("=" * 50)
#     print()

#     if create_database():
#         print()
#         print("🎉 Database is ready!")
#         print("👉 Now run: python run.py")

import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.models.base import Base                    # ← Updated import
from app.core.config import settings            # ← Your settings


# ====================== SQLAlchemy Setup ======================
engine = create_engine(settings.DATABASE_URL, echo=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ====================== Database Creation ======================
def create_database():
    print("🔄 Connecting to PostgreSQL...")

    try:
        conn = psycopg2.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()

        cursor.execute(
            f"SELECT 1 FROM pg_database WHERE datname = '{settings.DB_NAME}'"
        )
        exists = cursor.fetchone()

        if not exists:
            cursor.execute(f"CREATE DATABASE {settings.DB_NAME}")
            print(f"✅ Database '{settings.DB_NAME}' created!")
        else:
            print(f"✅ Database '{settings.DB_NAME}' already exists!")

        cursor.close()
        conn.close()
        return True

    except Exception as e:
        print(f"❌ Error: {e}")
        print("\nMake sure:")
        print("  1. PostgreSQL is running")
        print("  2. Your .env credentials are correct")
        print("  3. Try connecting via pgAdmin")
        return False


if __name__ == "__main__":
    print("=" * 50)
    print("  SecureWatch Database Setup")
    print("=" * 50)
    print(f"  Host: {settings.DB_HOST}:{settings.DB_PORT}")
    print(f"  User: {settings.DB_USER}")
    print(f"  Database: {settings.DB_NAME}")
    print("=" * 50)
    print()

    if create_database():
        print("\n🎉 Database is ready!")
        print("👉 Now run: python run.py")