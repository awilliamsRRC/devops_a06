import pytest
import mongomock
from bson.objectid import ObjectId

import banking-backend.app as app_module
from banking-backend.app import app

class MockMongo:
    def __init__(self):
        self.client = mongomock.MongoClient()
        self.db = self.client['bank_app']

@pytest.fixture
def mock_db(monkeypatch):
    mock = MockMongo()
    monkeypatch.setattr(app_module, 'mongo', mock)
    return mock

@pytest.fixture
def client(mock_db):
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def insert_user(mock_db, balance=0):
    user = {
        'first_name': 'Test',
        'last_name': 'User',
        'email': 'test@example.com',
        'password_hash': 'hash',
        'balance': balance,
        'transactions': []
    }
    result = mock_db.db.users.insert_one(user)
    return result.inserted_id

def test_successful_deposit_increases_balance(client, mock_db):
    user_id = insert_user(mock_db, balance=100)
    with client.session_transaction() as sess:
        sess['user_id'] = str(user_id)
    client.post('/deposit', data={'amount': '50'})
    user = mock_db.db.users.find_one({'_id': user_id})
    assert user['balance'] == 150

def test_withdraw_insufficient_funds_returns_error(client, mock_db):
    user_id = insert_user(mock_db, balance=20)
    with client.session_transaction() as sess:
        sess['user_id'] = str(user_id)
    response = client.post('/withdraw', data={'amount': '50'}, follow_redirects=True)
    user = mock_db.db.users.find_one({'_id': user_id})
    assert user['balance'] == 20
    assert b'Insufficient funds' in response.data