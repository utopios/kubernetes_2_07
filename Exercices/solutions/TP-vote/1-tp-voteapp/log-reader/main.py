import os
import psycopg2
import time
import sys

DB_HOST = os.environ.get("DB_HOST", "log-db")
DB_NAME = os.environ.get("DB_NAME", "postgres")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASS = os.environ.get("DB_PASS", "postgres")
LOG_PATH = os.environ.get("LOG_PATH", "/var/log/containers")

def insert_log(cursor, line):
    cursor.execute("INSERT INTO logs (content) VALUES (%s)", (line.strip(),))

def main():
    conn = psycopg2.connect(host=DB_HOST, dbname=DB_NAME, user=DB_USER, password=DB_PASS)
    cur = conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS logs (id SERIAL PRIMARY KEY, content TEXT);")
    conn.commit()

    sys.stdout.write("Reading logs...")
    while True:
        for log_file in os.listdir(LOG_PATH):
            full_path = os.path.join(LOG_PATH, log_file)
            try:
                with open(full_path) as f:
                    for line in f:
                        insert_log(conn, line.strip())
            except Exception:
                sys.stdout.write("Exception")
                continue
        time.sleep(30)
if __name__ == '__main__':
    main()
