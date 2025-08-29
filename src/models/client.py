from src.models.user import db
from datetime import datetime

class Client(db.Model):
    __tablename__ = 'clients'
    
    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(15), nullable=False)
    business_name = db.Column(db.String(100), nullable=False)
    plan_tier = db.Column(db.String(20), nullable=False)  # starter, pro, enterprise
    voice_option = db.Column(db.Boolean, default=False)
    invoice_url = db.Column(db.String(500), nullable=True)
    is_live = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationship with deployments
    deployments = db.relationship('Deployment', backref='client', lazy=True)

    def __repr__(self):
        return f'<Client {self.full_name} - {self.plan_tier}>'

    def to_dict(self):
        return {
            'id': self.id,
            'full_name': self.full_name,
            'phone': self.phone,
            'business_name': self.business_name,
            'plan_tier': self.plan_tier,
            'voice_option': self.voice_option,
            'invoice_url': self.invoice_url,
            'is_live': self.is_live,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Deployment(db.Model):
    __tablename__ = 'deployments'
    
    id = db.Column(db.Integer, primary_key=True)
    client_id = db.Column(db.Integer, db.ForeignKey('clients.id'), nullable=False)
    status = db.Column(db.String(20), nullable=False)  # pending, deploying, completed, failed
    start_time = db.Column(db.DateTime, default=datetime.utcnow)
    logs = db.Column(db.Text, nullable=True)

    def __repr__(self):
        return f'<Deployment {self.id} - {self.status}>'

    def to_dict(self):
        return {
            'id': self.id,
            'client_id': self.client_id,
            'status': self.status,
            'start_time': self.start_time.isoformat() if self.start_time else None,
            'logs': self.logs
        }

class Log(db.Model):
    __tablename__ = 'logs'
    
    id = db.Column(db.Integer, primary_key=True)
    source = db.Column(db.String(50), nullable=False)  # webhook, deployment, payment, etc.
    message = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f'<Log {self.source} - {self.timestamp}>'

    def to_dict(self):
        return {
            'id': self.id,
            'source': self.source,
            'message': self.message,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None
        }

