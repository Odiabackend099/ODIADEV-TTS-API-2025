import os
import sys
from dotenv import load_dotenv

# Load environment variables from config folder
config_path = os.path.join(os.path.dirname(__file__), 'config', '.env')
print(f"Loading .env from: {config_path}")
load_dotenv(config_path)

print(f"Working directory: {os.getcwd()}")
print(f"Python path: {sys.path[:3]}")

# Add src to path for imports
src_path = os.path.join(os.path.dirname(__file__), 'src')
if src_path not in sys.path:
    sys.path.insert(0, src_path)

try:
    from flask import Flask, send_from_directory, jsonify
    from flask_cors import CORS
    print("Flask imports successful")
    
    # Try importing our models and routes
    from models.user import db
    from models.client import Client, Deployment, Log
    from routes.user import user_bp
    from routes.odiadev import odiadev_bp
    print("Custom imports successful")
    
except ImportError as e:
    print(f"Import error: {e}")
    sys.exit(1)

app = Flask(__name__, static_folder=os.path.join(os.path.dirname(__file__), 'static'))
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'asdf#FGSgvasgf$5$WGT')

# Enable CORS for all routes
CORS(app, origins="*")

app.register_blueprint(user_bp, url_prefix='/api')
app.register_blueprint(odiadev_bp, url_prefix='/api')

# Database configuration
db_path = os.path.join(os.path.dirname(__file__), 'database', 'app.db')
app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{db_path}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
print(f"Database path: {db_path}")
print(f"Database exists: {os.path.exists(db_path)}")

db.init_app(app)

# Create database tables
with app.app_context():
    db.create_all()
    print("Database tables created/verified")

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "ODIADEV TTS API",
        "version": "1.0.0",
        "database": "connected" if os.path.exists(db_path) else "not found"
    })

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    static_folder_path = app.static_folder
    if static_folder_path is None:
        return jsonify({"error": "Static folder not configured"}), 404

    if path != "" and os.path.exists(os.path.join(static_folder_path, path)):
        return send_from_directory(static_folder_path, path)
    else:
        index_path = os.path.join(static_folder_path, 'index.html')
        if os.path.exists(index_path):
            return send_from_directory(static_folder_path, 'index.html')
        else:
            return jsonify({
                "message": "Welcome to ODIADEV TTS API",
                "status": "running",
                "endpoints": {
                    "health": "/health",
                    "tts": "/api/tts",
                    "signup": "/api/signup",
                    "status": "/api/status/<client_id>",
                    "logs": "/api/logs"
                }
            })

if __name__ == '__main__':
    print("Starting ODIADEV TTS API...")
    print(f"Environment: {os.getenv('FLASK_ENV', 'development')}")
    print(f"OpenAI Key configured: {'Yes' if os.getenv('OPENAI_API_KEY') else 'No'}")
    app.run(host='127.0.0.1', port=5002, debug=True)