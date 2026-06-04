import logging
import json
import os
import requests
import re
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from azure.storage.blob import BlobServiceClient
import azure.functions as func

# ─────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────
AZURE_STORAGE_CONNECTION_STRING = os.environ.get(
    'AZURE_STORAGE_CONNECTION_STRING', ''
)
OCR_API_KEY = os.environ.get('OCR_API_KEY', '')
DOCUMENTS_CONTAINER = "documents"
INSURANCE_CONTAINER = "insurance"
SENDER_EMAIL = os.environ.get('SENDER_EMAIL', '')
SENDER_PASSWORD = os.environ.get('SENDER_PASSWORD', '')

# ─────────────────────────────────────────
# Initialize Blob Client
# ─────────────────────────────────────────
blob_service_client = BlobServiceClient.from_connection_string(
    AZURE_STORAGE_CONNECTION_STRING
)

# ─────────────────────────────────────────
# Main Function
# ─────────────────────────────────────────
def main(msg: func.ServiceBusMessage):
    logging.info('✅ Insurance Function Triggered!')

    try:
        # Parse message
        message_body = msg.get_body().decode('utf-8')
        message_data = json.loads(message_body)
        logging.info(f"Message received: {message_data}")

        insurance_id = message_data.get('insurance_id')
        insurance_data = message_data.get('insurance_data')
        document_blob_name = message_data.get('document_blob_name')
        user_email = message_data.get('user_email')
        user_name = message_data.get('user_name')
        file_type = message_data.get('file_type')

        logging.info(f"Processing insurance ID: {insurance_id}")

        # Step 1: Get document from blob
        logging.info("Getting document from blob storage...")
        file_content = get_document_from_blob(document_blob_name)

        if not file_content:
            logging.error("Could not get document from blob")
            update_insurance_status(
                insurance_id,
                insurance_data,
                'Rejected',
                'Failed'
            )
            send_email(
                user_email,
                user_name,
                insurance_data,
                False,
                ["Could not process your document"]
            )
            return

        # Step 2: Extract text using OCR
        logging.info("Calling OCR API...")
        ocr_text = extract_text_with_ocr(
            file_content,
            file_type
        )
        logging.info(
            f"OCR Result: "
            f"{ocr_text[:100] if ocr_text else 'No text extracted'}"
        )

        # Step 3: Validate data
        logging.info("Validating extracted data...")
        is_valid, messages = validate_insurance_data(
            ocr_text,
            insurance_data
        )

        if is_valid:
            logging.info("✅ Validation PASSED")

            # Update status to Active
            update_insurance_status(
                insurance_id,
                insurance_data,
                'Active',
                'Passed'
            )

            # Send success email
            send_email(
                user_email,
                user_name,
                insurance_data,
                True,
                messages
            )

        else:
            logging.info("❌ Validation FAILED")

            # Update status to Rejected
            update_insurance_status(
                insurance_id,
                insurance_data,
                'Rejected',
                'Failed'
            )

            # Delete document from blob
            delete_document_from_blob(document_blob_name)

            # Send failure email
            send_email(
                user_email,
                user_name,
                insurance_data,
                False,
                messages
            )

    except Exception as e:
        logging.error(f"Function Error: {e}")
        raise e

# ─────────────────────────────────────────
# Get Document from Blob
# ─────────────────────────────────────────
def get_document_from_blob(blob_name):
    try:
        container_client = blob_service_client.get_container_client(
            DOCUMENTS_CONTAINER
        )
        blob_client = container_client.get_blob_client(blob_name)
        content = blob_client.download_blob().readall()
        logging.info(f"Document downloaded: {len(content)} bytes")
        return content
    except Exception as e:
        logging.error(f"Blob download error: {e}")
        return None

# ─────────────────────────────────────────
# Delete Document from Blob
# ─────────────────────────────────────────
def delete_document_from_blob(blob_name):
    try:
        container_client = blob_service_client.get_container_client(
            DOCUMENTS_CONTAINER
        )
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.delete_blob()
        logging.info(f"Document deleted: {blob_name}")
    except Exception as e:
        logging.error(f"Blob delete error: {e}")

# ─────────────────────────────────────────
# OCR Extraction
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
        logging.info(f"OCR Exit Code: {result.get('OCRExitCode')}")

        if result.get('OCRExitCode') == 1:
            parsed_results = result.get('ParsedResults', [])
            if parsed_results:
                text = parsed_results[0].get('ParsedText', '')
                logging.info(f"Extracted text length: {len(text)}")
                return text

        logging.error(
            f"OCR Error: {result.get('ErrorMessage', 'Unknown')}"
        )
        return None

    except Exception as e:
        logging.error(f"OCR Exception: {e}")
        return None

# ─────────────────────────────────────────
# Validate Insurance Data
# ─────────────────────────────────────────
def validate_insurance_data(ocr_text, insurance_data):
    errors = []
    warnings = []

    # Check if text was extracted
    if not ocr_text or len(ocr_text.strip()) < 10:
        errors.append(
            "Could not extract text from document. "
            "Please upload a clearer image."
        )
        return False, errors

    ocr_text_lower = ocr_text.lower()

    # Check insurance keywords
    insurance_terms = [
        'insurance', 'policy', 'coverage',
        'premium', 'insured', 'beneficiary',
        'claim', 'plan', 'protection', 'assured'
    ]

    found_terms = [
        term for term in insurance_terms
        if term in ocr_text_lower
    ]

    logging.info(f"Found insurance terms: {found_terms}")

    if len(found_terms) < 2:
        errors.append(
            "Document does not appear to be a valid "
            "insurance document. "
            f"Only found: {found_terms}"
        )

    # Check for dates
    date_pattern = r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}'
    dates_found = re.findall(date_pattern, ocr_text)
    if not dates_found:
        warnings.append(
            "No dates found in document"
        )

    # Check for amounts
    amount_pattern = r'[\$₹£€]\s*[\d,]+|[\d,]+'
    amounts_found = re.findall(amount_pattern, ocr_text)
    if not amounts_found:
        warnings.append(
            "No monetary amounts found in document"
        )

    if errors:
        return False, errors + warnings

    return True, warnings

# ─────────────────────────────────────────
# Update Insurance Status
# ─────────────────────────────────────────
def update_insurance_status(
    insurance_id,
    insurance_data,
    status,
    validation_status
):
    try:
        insurance_data['status'] = status
        insurance_data['validation_status'] = validation_status
        insurance_data['processed_at'] = datetime.now().strftime(
            "%Y-%m-%d %H:%M:%S"
        )

        container_client = blob_service_client.get_container_client(
            INSURANCE_CONTAINER
        )
        blob_client = container_client.get_blob_client(
            f"{insurance_id}.json"
        )
        blob_client.upload_blob(
            json.dumps(insurance_data, indent=2),
            overwrite=True
        )
        logging.info(
            f"Insurance {insurance_id} "
            f"updated to {status}"
        )
    except Exception as e:
        logging.error(f"Status update error: {e}")

# ─────────────────────────────────────────
# Send Email
# ─────────────────────────────────────────
def send_email(
    user_email,
    user_name,
    insurance_data,
    is_success,
    messages
):
    try:
        msg = MIMEMultipart('alternative')
        msg['From'] = SENDER_EMAIL
        msg['To'] = user_email

        if is_success:
            msg['Subject'] = \
                "✅ Insurance Approved - InsurePortal"

            html_body = f"""
            <html>
            <body style="font-family:Arial; padding:20px;">
                <div style="background:#28a745;
                            color:white;
                            padding:20px;
                            border-radius:10px;">
                    <h2>✅ Insurance Application Approved!</h2>
                </div>
                <div style="padding:20px;
                            border:1px solid #ddd;
                            border-radius:10px;
                            margin-top:10px;">
                    <p>Dear <strong>{user_name}</strong>,</p>
                    <p>Your insurance application has been
                    <strong>approved</strong>!</p>
                    <table style="width:100%;
                                  border-collapse:collapse;">
                        <tr style="background:#f8f9fa;">
                            <td style="padding:10px;
                                       border:1px solid #ddd;">
                                Policy Number
                            </td>
                            <td style="padding:10px;
                                       border:1px solid #ddd;">
                                {insurance_data.get('policy_number')}
                            </td>
                        </tr>
                        <tr>
                            <td style="padding:10px;
                                       border:1px solid #ddd;">
                                Insurance Type
                            </td>
                            <td style="padding:10px;
                                       border:1px solid #ddd;">
                                {insurance_data.get('insurance_type')}
                            </td>
                        </tr>
                        <tr style="background:#f8f9fa;">
                            <td style="padding:10px;
                                       border:1px solid #ddd;">
                                Coverage Amount
                            </td>
                            <td style="padding:10px;
                                       border:1px solid #ddd;">
                                ₹{insurance_data.get('coverage_amount')}
                            </td>
                        </tr>
                        <tr>
                            <td style="padding:10px;
                                       border:1px solid #ddd;">
                                Premium
                            </td>
                            <td style="padding:10px;
                                       border:1px solid #ddd;">
                                ₹{insurance_data.get('premium')}/month
                            </td>
                        </tr>
                        <tr style="background:#f8f9fa;">
                            <td style="padding:10px;
                                       border:1px solid #ddd;">
                                Status
                            </td>
                            <td style="padding:10px;
                                       border:1px solid #ddd;
                                       color:green;">
                                ✅ Active
                            </td>
                        </tr>
                    </table>
                    <br>
                    <p>Thank you for choosing InsurePortal!</p>
                </div>
            </body>
            </html>
            """
        else:
            msg['Subject'] = \
                "❌ Insurance Rejected - InsurePortal"

            error_list = "".join(
                [f"<li>{m}</li>" for m in messages]
            )

            html_body = f"""
            <html>
            <body style="font-family:Arial; padding:20px;">
                <div style="background:#dc3545;
                            color:white;
                            padding:20px;
                            border-radius:10px;">
                    <h2>❌ Insurance Application Rejected</h2>
                </div>
                <div style="padding:20px;
                            border:1px solid #ddd;
                            border-radius:10px;
                            margin-top:10px;">
                    <p>Dear <strong>{user_name}</strong>,</p>
                    <p>Your insurance application has been
                    <strong>rejected</strong>.</p>
                    <h3>Reasons:</h3>
                    <ul style="color:red;">
                        {error_list}
                    </ul>
                    <p>Policy Number:
                        {insurance_data.get('policy_number')}
                    </p>
                    <p>Please resubmit with a valid document.</p>
                    <p>Thank you for choosing InsurePortal!</p>
                </div>
            </body>
            </html>
            """

        msg.attach(MIMEText(html_body, 'html'))

        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.sendmail(
            SENDER_EMAIL,
            user_email,
            msg.as_string()
        )
        server.quit()
        logging.info(f"✅ Email sent to {user_email}")

    except Exception as e:
        logging.error(f"Email Error: {e}")