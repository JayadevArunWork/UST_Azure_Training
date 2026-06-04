from flask import (
    Flask, render_template,
    request, redirect,
    session, url_for
)
import json
import os
import re
import requests
import smtplib
import threading
import uuid
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from werkzeug.security import (
    generate_password_hash,
    check_password_hash
)

app = Flask(__name__)
app.secret_key = "insurance_secret_key_2024"

# ─────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────
AZURE_STORAGE_CONNECTION_STRING = os.environ.get(
    'AZURE_STORAGE_CONNECTION_STRING', ''
)
AZURE_SERVICEBUS_CONNECTION_STRING = os.environ.get(
    'AZURE_SERVICEBUS_CONNECTION_STRING', ''
)
SERVICEBUS_QUEUE_NAME = os.environ.get(
    'SERVICEBUS_QUEUE_NAME', 'insurance-queue'
)
OCR_API_KEY = os.environ.get('OCR_API_KEY', '')
SENDER_EMAIL = os.environ.get('SENDER_EMAIL', '')
SENDER_PASSWORD = os.environ.get('SENDER_PASSWORD', '')

USERS_CONTAINER = "users"
INSURANCE_CONTAINER = "insurance"
DOCUMENTS_CONTAINER = "documents"

# ─────────────────────────────────────────
# Get Blob Client (Lazy Load)
# ─────────────────────────────────────────
def get_blob_service_client():
    try:
        from azure.storage.blob import BlobServiceClient
        return BlobServiceClient.from_connection_string(
            AZURE_STORAGE_CONNECTION_STRING
        )
    except Exception as e:
        print(f"Blob client error: {e}")
        return None

# ─────────────────────────────────────────
# Blob Helper Functions
# ─────────────────────────────────────────
def get_blob_data(container_name, blob_name):
    try:
        client = get_blob_service_client()
        if not client:
            return None
        container_client = client.get_container_client(
            container_name
        )
        blob_client = container_client.get_blob_client(
            blob_name
        )
        data = blob_client.download_blob().readall()
        return json.loads(data)
    except Exception:
        return None

def save_blob_data(container_name, blob_name, data):
    try:
        client = get_blob_service_client()
        if not client:
            return False
        container_client = client.get_container_client(
            container_name
        )
        blob_client = container_client.get_blob_client(
            blob_name
        )
        blob_client.upload_blob(
            json.dumps(data, indent=2),
            overwrite=True
        )
        return True
    except Exception as e:
        print(f"Save blob error: {e}")
        return False

def get_all_users():
    try:
        client = get_blob_service_client()
        if not client:
            return []
        container_client = client.get_container_client(
            USERS_CONTAINER
        )
        users = []
        for blob in container_client.list_blobs():
            user_data = get_blob_data(
                USERS_CONTAINER, blob.name
            )
            if user_data:
                users.append(user_data)
        return users
    except Exception:
        return []

def get_all_insurance():
    try:
        client = get_blob_service_client()
        if not client:
            return []
        container_client = client.get_container_client(
            INSURANCE_CONTAINER
        )
        all_insurance = []
        for blob in container_client.list_blobs():
            ins_data = get_blob_data(
                INSURANCE_CONTAINER, blob.name
            )
            if ins_data:
                all_insurance.append(ins_data)
        return all_insurance
    except Exception:
        return []

# ─────────────────────────────────────────
# Service Bus Function
# ─────────────────────────────────────────
def send_to_service_bus(message_data):
    try:
        from azure.servicebus import (
            ServiceBusClient,
            ServiceBusMessage
        )
        sb_client = ServiceBusClient.from_connection_string(
            AZURE_SERVICEBUS_CONNECTION_STRING
        )
        with sb_client:
            sender = sb_client.get_queue_sender(
                queue_name=SERVICEBUS_QUEUE_NAME
            )
            with sender:
                message = ServiceBusMessage(
                    json.dumps(message_data)
                )
                sender.send_messages(message)
                print("Message sent to Service Bus")
        return True
    except Exception as e:
        print(f"Service Bus Error: {e}")
        return False

# ─────────────────────────────────────────
# OCR Function
# ─────────────────────────────────────────
def extract_text_with_ocr(file_content, file_type):
    try:
        ocr_url = "https://api.ocr.space/parse/image"

        if file_type == 'pdf':
            mime_type = 'application/pdf'
        else:
            mime_type = f'image/{file_type}'

        payload = {
            'apikey': OCR_API_KEY,
            'language': 'eng',
            'isOverlayRequired': False,
            'detectOrientation': True,
            'scale': True,
            'isTable': True,
            'OCREngine': 2
        }
        files = {
            'file': (
                f'document.{file_type}',
                file_content,
                mime_type
            )
        }
        response = requests.post(
            ocr_url,
            data=payload,
            files=files,
            timeout=60
        )
        result = response.json()
        print(f"OCR Code: {result.get('OCRExitCode')}")

        if result.get('OCRExitCode') == 1:
            parsed = result.get('ParsedResults', [])
            if parsed:
                text = parsed[0].get('ParsedText', '')
                print(f"OCR Text: {text[:100]}")
                return text

        print(f"OCR Err: {result.get('ErrorMessage')}")
        return None
    except Exception as e:
        print(f"OCR Exception: {e}")
        return None

# ─────────────────────────────────────────
# Validation Function
# ─────────────────────────────────────────
def validate_insurance_data(ocr_text, insurance_data):
    errors = []
    warnings = []

    if not ocr_text or len(ocr_text.strip()) < 10:
        errors.append(
            "Could not extract text from document."
        )
        return False, errors

    ocr_lower = ocr_text.lower()

    terms = [
        'insurance', 'policy', 'coverage',
        'premium', 'insured', 'beneficiary',
        'claim', 'plan', 'protection', 'assured'
    ]

    found = [t for t in terms if t in ocr_lower]
    print(f"Found terms: {found}")

    if len(found) < 2:
        errors.append(
            "Not a valid insurance document."
        )

    dates = re.findall(
        r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}',
        ocr_text
    )
    if not dates:
        warnings.append("No dates found")

    amounts = re.findall(
        r'[\$₹£€]\s*[\d,]+|[\d,]+',
        ocr_text
    )
    if not amounts:
        warnings.append("No amounts found")

    if errors:
        return False, errors + warnings
    return True, warnings

# ─────────────────────────────────────────
# Email Function
# ─────────────────────────────────────────
def send_email(to_email, name, ins_data, success, msgs):
    try:
        msg = MIMEMultipart('alternative')
        msg['From'] = SENDER_EMAIL
        msg['To'] = to_email

        if success:
            msg['Subject'] = "Insurance Approved"
            html = f"""
            <html><body>
            <h2 style="color:green;">
                Insurance Approved!
            </h2>
            <p>Dear {name},</p>
            <p>Your insurance has been approved!</p>
            <p>Policy: {ins_data.get('policy_number')}</p>
            <p>Type: {ins_data.get('insurance_type')}</p>
            <p>Coverage: {ins_data.get('coverage_amount')}</p>
            <p>Premium: {ins_data.get('premium')}/month</p>
            <p>Status: Active</p>
            <p>Thank you for choosing InsurePortal!</p>
            </body></html>
            """
        else:
            msg['Subject'] = "Insurance Rejected"
            reasons = "".join(
                [f"<li>{m}</li>" for m in msgs]
            )
            html = f"""
            <html><body>
            <h2 style="color:red;">
                Insurance Rejected
            </h2>
            <p>Dear {name},</p>
            <p>Your insurance has been rejected.</p>
            <h3>Reasons:</h3>
            <ul style="color:red;">{reasons}</ul>
            <p>Please resubmit with valid document.</p>
            <p>Thank you for choosing InsurePortal!</p>
            </body></html>
            """

        msg.attach(MIMEText(html, 'html'))
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.sendmail(SENDER_EMAIL, to_email, msg.as_string())
        server.quit()
        print(f"Email sent to {to_email}")
    except Exception as e:
        print(f"Email Error: {e}")

# ─────────────────────────────────────────
# Background Processing
# ─────────────────────────────────────────
def process_insurance(msg_data):
    print("Processing started...")
    try:
        ins_id = msg_data.get('insurance_id')
        ins_data = msg_data.get('insurance_data')
        doc_blob = msg_data.get('document_blob_name')
        email = msg_data.get('user_email')
        name = msg_data.get('user_name')
        ftype = msg_data.get('file_type')
        content = bytes(msg_data.get('file_content', []))

        # OCR
        print("Running OCR...")
        ocr_text = extract_text_with_ocr(content, ftype)

        # Validate
        print("Validating...")
        valid, msgs = validate_insurance_data(
            ocr_text, ins_data
        )

        if valid:
            print("PASSED")
            ins_data['status'] = 'Active'
            ins_data['validation_status'] = 'Passed'
            ins_data['processed_at'] = \
                datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            save_blob_data(
                INSURANCE_CONTAINER,
                f"{ins_id}.json",
                ins_data
            )

            send_to_service_bus({
                "type": "success",
                "email": email,
                "id": ins_id
            })

            send_email(email, name, ins_data, True, msgs)

        else:
            print("FAILED")
            ins_data['status'] = 'Rejected'
            ins_data['validation_status'] = 'Failed'
            ins_data['rejection_reasons'] = msgs
            ins_data['processed_at'] = \
                datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            save_blob_data(
                INSURANCE_CONTAINER,
                f"{ins_id}.json",
                ins_data
            )

            # Delete document
            try:
                client = get_blob_service_client()
                if client:
                    cc = client.get_container_client(
                        DOCUMENTS_CONTAINER
                    )
                    bc = cc.get_blob_client(doc_blob)
                    bc.delete_blob()
                    print("Document deleted")
            except Exception as e:
                print(f"Delete err: {e}")

            send_to_service_bus({
                "type": "failed",
                "email": email,
                "id": ins_id,
                "reasons": msgs
            })

            send_email(email, name, ins_data, False, msgs)

    except Exception as e:
        print(f"Process Error: {e}")

# ─────────────────────────────────────────
# Routes
# ─────────────────────────────────────────
@app.route('/')
def home():
    return render_template('home.html')

@app.route('/health')
def health():
    return "OK", 200

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        name = request.form['name']
        email = request.form['email']
        password = request.form['password']
        phone = request.form['phone']

        existing = get_blob_data(
            USERS_CONTAINER, f"{email}.json"
        )
        if existing:
            return render_template(
                'register.html',
                error="User already exists!"
            )

        user_data = {
            "id": str(uuid.uuid4()),
            "name": name,
            "email": email,
            "phone": phone,
            "password": generate_password_hash(password),
            "created_at": datetime.now().strftime(
                "%Y-%m-%d %H:%M:%S"
            ),
            "role": "customer"
        }

        save_blob_data(
            USERS_CONTAINER,
            f"{email}.json",
            user_data
        )
        return redirect(url_for('login'))

    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']

        if (email == "admin@insurance.com"
                and password == "admin123"):
            session['user'] = "admin"
            session['role'] = "admin"
            session['name'] = "Admin"
            return redirect(url_for('admin'))

        user_data = get_blob_data(
            USERS_CONTAINER, f"{email}.json"
        )

        if user_data and check_password_hash(
            user_data['password'], password
        ):
            session['user'] = email
            session['role'] = "customer"
            session['name'] = user_data['name']
            return redirect(url_for('dashboard'))
        else:
            return render_template(
                'login.html',
                error="Invalid credentials!"
            )

    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect(url_for('login'))

    email = session['user']
    user_data = get_blob_data(
        USERS_CONTAINER, f"{email}.json"
    )
    all_ins = get_all_insurance()
    user_ins = [
        i for i in all_ins
        if i.get('email') == email
    ]

    return render_template(
        'dashboard.html',
        user=user_data,
        insurance_list=user_ins
    )

@app.route('/add_insurance', methods=['GET', 'POST'])
def add_insurance():
    if 'user' not in session:
        return redirect(url_for('login'))

    if request.method == 'POST':
        email = session['user']
        user_data = get_blob_data(
            USERS_CONTAINER, f"{email}.json"
        )

        document = request.files.get('document')

        if not document:
            return render_template(
                'add_insurance.html',
                error="Please upload document!"
            )

        file_content = document.read()
        file_type = document.filename.split(
            '.'
        )[-1].lower()

        if file_type not in [
            'jpg', 'jpeg', 'png', 'pdf'
        ]:
            return render_template(
                'add_insurance.html',
                error="Only JPG, PNG, PDF allowed!"
            )

        ins_id = str(uuid.uuid4())
        ins_data = {
            "id": ins_id,
            "email": email,
            "user_name": user_data.get('name', ''),
            "insurance_type": request.form[
                'insurance_type'
            ],
            "policy_number": "POL-" + str(
                uuid.uuid4()
            )[:8].upper(),
            "coverage_amount": request.form[
                'coverage_amount'
            ],
            "start_date": request.form['start_date'],
            "end_date": request.form['end_date'],
            "nominee": request.form['nominee'],
            "premium": request.form['premium'],
            "status": "Pending",
            "created_at": datetime.now().strftime(
                "%Y-%m-%d %H:%M:%S"
            ),
            "document_name": document.filename,
            "validation_status": "Processing"
        }

        # Save pending record
        save_blob_data(
            INSURANCE_CONTAINER,
            f"{ins_id}.json",
            ins_data
        )

        # Upload document
        doc_blob = f"{ins_id}_{document.filename}"
        try:
            client = get_blob_service_client()
            if client:
                cc = client.get_container_client(
                    DOCUMENTS_CONTAINER
                )
                bc = cc.get_blob_client(doc_blob)
                bc.upload_blob(
                    file_content,
                    overwrite=True
                )
        except Exception as e:
            print(f"Upload err: {e}")

        # Background thread
        msg_data = {
            "insurance_id": ins_id,
            "insurance_data": ins_data,
            "document_blob_name": doc_blob,
            "user_email": email,
            "user_name": user_data.get('name', ''),
            "file_type": file_type,
            "file_content": list(file_content)
        }

        thread = threading.Thread(
            target=process_insurance,
            args=(msg_data,)
        )
        thread.daemon = True
        thread.start()
        print("Thread started!")

        return render_template(
            'add_insurance.html',
            success="Document uploaded! "
                   "Validating... "
                   "Check email for results."
        )

    return render_template('add_insurance.html')

@app.route('/customer')
def customer():
    if 'user' not in session:
        return redirect(url_for('login'))

    email = session['user']
    all_ins = get_all_insurance()
    user_ins = [
        i for i in all_ins
        if i.get('email') == email
    ]

    return render_template(
        'customer.html',
        insurance_list=user_ins
    )

@app.route('/admin')
def admin():
    if ('user' not in session
            or session.get('role') != 'admin'):
        return redirect(url_for('login'))

    all_ins = get_all_insurance()
    all_users = get_all_users()

    ins_types = {}
    for ins in all_ins:
        t = ins.get('insurance_type', 'Unknown')
        ins_types[t] = ins_types.get(t, 0) + 1

    return render_template(
        'admin.html',
        insurance_list=all_ins,
        all_users=all_users,
        total_users=len(all_users),
        total_insurance=len(all_ins),
        insurance_types=ins_types
    )

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('home'))

# ─────────────────────────────────────────
# Main
# ─────────────────────────────────────────
if __name__ == '__main__':
    app.run(
        host='0.0.0.0',
        port=8000,
        debug=False
    )