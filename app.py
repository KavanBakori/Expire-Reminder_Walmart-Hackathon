from flask import Flask, request, jsonify
from datetime import datetime
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

def format_date(date_str):
    return datetime.strptime(date_str, "%d/%m/%Y")

@app.route('/api/qrdata', methods=['POST'])
def process_qr_data():
    data = request.json.get('qr_data', "")
    products = data.strip().split('\n\n')
    
    product_data = []
    
    for product_info in products:
        if not product_info.strip():
            continue
        product_lines = product_info.split('\n')
        if len(product_lines) < 3:
            continue
        
        try:
            product_name = product_lines[0].split(': ', 1)[1]
            description = product_lines[1].split(': ', 1)[1]
            expiration_date_str = product_lines[2].split(': ', 1)[1]
        
            expiration_date = format_date(expiration_date_str)
            current_date = datetime.now()
            days_remaining = (expiration_date - current_date).days
            
            product_data.append({
                'product_name': product_name,
                'description': description,
                'expiration_date': expiration_date_str,
                'days_remaining': days_remaining
            })
        except (ValueError, IndexError) as e:
            print(f"Error processing product: {str(e)}")
            continue
    
    if not product_data:
        return jsonify({'error': 'No valid product data found in QR code'}), 400
    
    return jsonify(product_data)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')