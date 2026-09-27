import os
import sys
import unittest

# Ensure backend directory is in python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

os.environ["API_KEY"] = "test_secret_key"
os.environ["SEED_DEMO_DATA"] = "false"

from fastapi.testclient import TestClient
from sqlmodel import SQLModel
from main import app
from database import engine

class TestBackendApi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        SQLModel.metadata.create_all(engine)
        cls.client = TestClient(app)

    def test_01_health_check_unauthenticated(self):
        response = self.client.get("/api/health")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "healthy")

    def test_02_api_key_security(self):
        # Missing API Key -> 401
        response = self.client.get("/api/transactions")
        self.assertEqual(response.status_code, 401)

        # Invalid API Key -> 401
        response = self.client.get("/api/transactions", headers={"X-API-Key": "wrong_key"})
        self.assertEqual(response.status_code, 401)

        # Valid API Key -> 200
        response = self.client.get("/api/transactions", headers={"X-API-Key": "test_secret_key"})
        self.assertEqual(response.status_code, 200)

    def test_03_uuid_upsert_and_by_uuid_put(self):
        headers = {"X-API-Key": "test_secret_key"}
        test_uuid = "test-uuid-reconciliation-12345"

        # 1. Insert initial transaction with UUID
        tx_payload = {
            "uuid": test_uuid,
            "title": "Initial Swiggy",
            "amount": 350.0,
            "merchant": "Swiggy",
            "category": "Food & Dining",
            "date": "2026-09-27",
            "status": "auto"
        }
        resp = self.client.post("/api/transactions", json=tx_payload, headers=headers)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["uuid"], test_uuid)
        self.assertEqual(data["amount"], 350.0)

        # 2. Upsert via POST with existing UUID (should update existing row, not create duplicate)
        tx_payload["amount"] = 420.0
        tx_payload["title"] = "Updated Swiggy via Upsert"
        resp2 = self.client.post("/api/transactions", json=tx_payload, headers=headers)
        self.assertEqual(resp2.status_code, 200)
        data2 = resp2.json()
        self.assertEqual(data2["uuid"], test_uuid)
        self.assertEqual(data2["amount"], 420.0)

        # 3. Update via PUT by-uuid endpoint
        put_payload = {
            "category": "Food & Dining",
            "status": "confirmed",
            "notes": "Team Lunch Order"
        }
        resp3 = self.client.put(f"/api/transactions/by-uuid/{test_uuid}", json=put_payload, headers=headers)
        self.assertEqual(resp3.status_code, 200)
        data3 = resp3.json()
        self.assertEqual(data3["uuid"], test_uuid)
        self.assertEqual(data3["notes"], "Team Lunch Order")
        self.assertEqual(data3["status"], "confirmed")

    def test_04_budget_period_rollover(self):
        headers = {"X-API-Key": "test_secret_key"}
        
        # Request budgets for future month (should rollover allocations with spent=0)
        resp = self.client.get("/api/budgets?period=2026-11", headers=headers)
        self.assertEqual(resp.status_code, 200)
        budgets = resp.json()
        self.assertGreater(len(budgets), 0)
        for b in budgets:
            self.assertEqual(b["period"], "2026-11")

if __name__ == "__main__":
    unittest.main()
