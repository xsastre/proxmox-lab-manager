# backend/app.py
from flask import Flask, request, jsonify
import sqlite3
import os

app = Flask(__name__)
DB_FILE = 'lab_manager.db'

def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    # Taula per desar les diferents pràctiques/laboratoris
    c.execute('''CREATE TABLE IF NOT EXISTS practiques
                 (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                  nom TEXT, curs TEXT, modul TEXT, 
                  descripcio TEXT, num_alumnes INTEGER, 
                  vms_per_alumne INTEGER, plantilla_id INTEGER)''')
    conn.commit()
    conn.close()

@app.route('/api/local/practiques', methods=['GET'])
def get_practiques():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute("SELECT * FROM practiques")
    files = c.fetchall()
    conn.close()
    
    practiques = []
    for f in files:
        practiques.append({
            "id": f[0], "nom": f[1], "curs": f[2], "modul": f[3],
            "descripcio": f[4], "num_alumnes": f[5],
            "vms_per_alumne": f[6], "plantilla_id": f[7]
        })
    return jsonify(practiques)

@app.route('/api/local/practiques', methods=['POST'])
def add_practica():
    data = request.json
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''INSERT INTO practiques (nom, curs, modul, descripcio, num_alumnes, vms_per_alumne, plantilla_id)
                 VALUES (?, ?, ?, ?, ?, ?, ?)''', 
              (data['nom'], data['curs'], data['modul'], data['descripcio'], 
               data['num_alumnes'], data['vms_per_alumne'], data['plantilla_id']))
    conn.commit()
    new_id = c.lastrowid
    conn.close()
    return jsonify({"success": True, "id": new_id})

if __name__ == '__main__':
    init_db()
    # Executa el backend al port 5000 només per a localhost (Nginx farà de proxy)
    app.run(host='127.0.0.1', port=5000)
