from flask import Flask, render_template, request, redirect, session, url_for
from azure.storage.blob import BlobServiceClient
import json
import os
from werkzeug.security import generate_password_hash, check_password_hash
import uuid
from datetime import datetime

app = Flask(__name__)
app.secret_key = "insurance_secret_key_2024"

# Azure Blob Storage Configuration
AZURE_CONNECTION_STRING = "<AZURE-BLOB-STORAGE-CONNECTION-STRING>"
USERS_CONTAINER = "users"
INSURANCE_CONTAINER = "insurance"

# Initialize BlobServiceClient
blob_service_client = BlobServiceClient.from_connection_string(AZURE_CONNECTION_STRING)

# ─────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────

def get_blob_data(container_name, blob_name):
    """Fetch data from blob storage"""
    try:
        container_client = blob_service_client.get_container_client(container_name)
        blob_client = container_client.get_blob_client(blob_name)
        data = blob_client.download_blob().readall()
        return json.loads(data)
    except Exception:
        return None

def save_blob_data(container_name, blob_name, data):
    """Save data to blob storage"""
    try:
        container_client = blob_service_client.get_container_client(container_name)
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(
            json.dumps(data, indent=2),
            overwrite=True
        )
        return True
    except Exception as e:
        print(f"Error saving blob: {e}")
        return False

def get_all_users():
    """Get all users from blob storage"""
    try:
        container_client = blob_service_client.get_container_client(USERS_CONTAINER)
        users = {}
        for blob in container_client.list_blobs():
            user_data = get_blob_data(USERS_CONTAINER, blob.name)
            if user_data:
                users[blob.name.replace('.json', '')] = user_data
        return users
    except Exception:
        return {}

def get_all_insurance():
    """Get all insurance records from blob storage"""
    try:
        container_client = blob_service_client.get_container_client(INSURANCE_CONTAINER)
        all_insurance = []
        for blob in container_client.list_blobs():
            insurance_data = get_blob_data(INSURANCE_CONTAINER, blob.name)
            if insurance_data:
                all_insurance.append(insurance_data)
        return all_insurance
    except Exception:
        return []

def create_containers():
    """Create containers if they don't exist"""
    for container in [USERS_CONTAINER, INSURANCE_CONTAINER]:
        try:
            blob_service_client.create_container(container)
        except Exception:
            pass

# ─────────────────────────────────────────
# Routes
# ─────────────────────────────────────────

@app.route('/')
def home():
    return render_template('home.html')

# ── REGISTER ──
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        name = request.form['name']
        email = request.form['email']
        password = request.form['password']
        phone = request.form['phone']

        # Check if user already exists
        existing_user = get_blob_data(USERS_CONTAINER, f"{email}.json")
        if existing_user:
            return render_template('register.html', error="User already exists! Please login.")

        # Create new user
        user_data = {
            "id": str(uuid.uuid4()),
            "name": name,
            "email": email,
            "phone": phone,
            "password": generate_password_hash(password),
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "role": "customer"
        }

        # Save to blob storage
        save_blob_data(USERS_CONTAINER, f"{email}.json", user_data)
        return redirect(url_for('login'))

    return render_template('register.html')

# ── LOGIN ──
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']

        # Admin login check
        if email == "admin@insurance.com" and password == "admin123":
            session['user'] = "admin"
            session['role'] = "admin"
            session['name'] = "Admin"
            return redirect(url_for('admin'))

        # Fetch user from blob storage
        user_data = get_blob_data(USERS_CONTAINER, f"{email}.json")

        if user_data and check_password_hash(user_data['password'], password):
            session['user'] = email
            session['role'] = "customer"
            session['name'] = user_data['name']
            return redirect(url_for('dashboard'))
        else:
            return render_template('login.html', error="Invalid credentials!")

    return render_template('login.html')

# ── DASHBOARD ──
@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect(url_for('login'))

    email = session['user']
    user_data = get_blob_data(USERS_CONTAINER, f"{email}.json")

    # Get user insurance records
    all_insurance = get_all_insurance()
    user_insurance = [i for i in all_insurance if i.get('email') == email]

    return render_template(
        'dashboard.html',
        user=user_data,
        insurance_list=user_insurance
    )

# ── ADD INSURANCE ──
@app.route('/add_insurance', methods=['GET', 'POST'])
def add_insurance():
    if 'user' not in session:
        return redirect(url_for('login'))

    if request.method == 'POST':
        email = session['user']
        insurance_data = {
            "id": str(uuid.uuid4()),
            "email": email,
            "insurance_type": request.form['insurance_type'],
            "policy_number": "POL-" + str(uuid.uuid4())[:8].upper(),
            "coverage_amount": request.form['coverage_amount'],
            "start_date": request.form['start_date'],
            "end_date": request.form['end_date'],
            "nominee": request.form['nominee'],
            "premium": request.form['premium'],
            "status": "Active",
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }

        # Save insurance to blob storage
        save_blob_data(
            INSURANCE_CONTAINER,
            f"{insurance_data['id']}.json",
            insurance_data
        )
        return redirect(url_for('customer'))

    return render_template('add_insurance.html')

# ── CUSTOMER PAGE ──
@app.route('/customer')
def customer():
    if 'user' not in session:
        return redirect(url_for('login'))

    email = session['user']
    all_insurance = get_all_insurance()
    user_insurance = [i for i in all_insurance if i.get('email') == email]

    return render_template('customer.html', insurance_list=user_insurance)

# ── ADMIN PAGE ──
@app.route('/admin')
def admin():
    if 'user' not in session or session.get('role') != 'admin':
        return redirect(url_for('login'))

    all_insurance = get_all_insurance()
    all_users = get_all_users()

    return render_template(
        'admin.html',
        insurance_list=all_insurance,
        total_users=len(all_users),
        total_insurance=len(all_insurance)
    )

# ── LOGOUT ──
@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('home'))

# ─────────────────────────────────────────
# Main
# ─────────────────────────────────────────
if __name__ == '__main__':
    create_containers()
    app.run(debug=True)