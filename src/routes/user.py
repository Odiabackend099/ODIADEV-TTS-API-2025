from flask import Blueprint, request, jsonify
from src.models.user import db, User

user_bp = Blueprint('user', __name__)

@user_bp.route('/users', methods=['GET'])
def get_users():
    """Get all users"""
    try:
        users = User.query.all()
        return jsonify({
            "users": [user.to_dict() for user in users]
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@user_bp.route('/users', methods=['POST'])
def create_user():
    """Create a new user"""
    try:
        data = request.get_json()
        
        if not data or not data.get('username') or not data.get('email'):
            return jsonify({"error": "Username and email are required"}), 400
        
        user = User(
            username=data['username'],
            email=data['email']
        )
        
        db.session.add(user)
        db.session.commit()
        
        return jsonify({
            "message": "User created successfully",
            "user": user.to_dict()
        }), 201
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

