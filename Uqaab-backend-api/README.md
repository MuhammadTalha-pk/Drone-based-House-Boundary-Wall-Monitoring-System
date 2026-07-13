Clone the repo.

Run these commands:

pip install -r requirements.txt
python setup_db.py   # This creates the DB
alembic upgrade head # This creates all tables/migrations
python run.py        # Starts the API
