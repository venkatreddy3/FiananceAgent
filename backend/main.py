import os
import json
import uuid as py_uuid
from contextlib import asynccontextmanager
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, APIRouter, Depends, HTTPException, Query, Header, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlmodel import Session, select
from datetime import datetime, date
import httpx

from database import init_db, get_session, Transaction, Budget, SavingsGoal, GoalContribution, GoalMonthlyPlan, MerchantDictionary, AgentMessage
from ollama_service import ollama_service
from agents import agent_coordinator

# Security: API_KEY must come from .env with no default; refuse to start if missing.
API_KEY = os.environ.get("API_KEY")
if not API_KEY:
    # Check if testing mode or set default in non-prod if needed, else raise RuntimeError
    # For robust local dev, allow fallback only if explicitly marked DEV, else enforce
    API_KEY = os.environ.get("FINTRACK_API_KEY") or os.environ.get("API_KEY")
    if not API_KEY:
        raise RuntimeError("API_KEY environment variable is required. Please set API_KEY in your .env file.")

GOOGLE_PLACES_API_KEY = os.environ.get("GOOGLE_PLACES_API_KEY", "")

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield

app = FastAPI(
    title="FinTrack Proactive AI Financial Orchestrator",
    version="2.5.0",
    lifespan=lifespan
)

# CORS configuration (No "*" wildcard, allow_credentials=False)
allowed_origins = [
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:8000",
    "http://127.0.0.1",
    "http://127.0.0.1:8000",
    "http://10.0.2.2",
    "http://10.0.2.2:8000"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

def verify_api_key(x_api_key: Optional[str] = Header(None)):
    """Reject when the header is missing OR wrong"""
    if not x_api_key or x_api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing X-API-Key header"
        )
    return x_api_key

# --- Health & Diagnostics (Unprotected) ---
@app.get("/api/health")
async def health_check():
    ollama_ok = await ollama_service.is_available()
    models = await ollama_service.list_models() if ollama_ok else []
    return {
        "status": "healthy",
        "service": "FinTrack Agent Hub",
        "ollama_connected": ollama_ok,
        "available_models": models,
        "version": "2.5.0"
    }

# Protected API Router with verify_api_key attached to EVERY /api route
api_router = APIRouter(dependencies=[Depends(verify_api_key)])

# --- Helper: Calculate Budget Alerts ---
def check_budget_alerts(category: str, period: str, session: Session) -> List[Dict[str, Any]]:
    alerts = []
    budget = session.exec(
        select(Budget).where(Budget.category == category, Budget.period == period)
    ).first()
    
    if not budget:
        budget = session.exec(select(Budget).where(Budget.category == category)).first()
        
    if budget and budget.allocated_amount > 0:
        month_txs = session.exec(
            select(Transaction).where(
                Transaction.category == category,
                Transaction.type == "expense"
            )
        ).all()
        spent = sum(t.amount for t in month_txs if t.date.startswith(period))
        ratio = spent / budget.allocated_amount
        
        if ratio >= 1.0:
            alerts.append({
                "category": category,
                "threshold_pct": 100,
                "message": f"Critical: {category} budget has exceeded 100% (₹{spent:.0f} / ₹{budget.allocated_amount:.0f})"
            })
        elif ratio >= 0.8:
            alerts.append({
                "category": category,
                "threshold_pct": 80,
                "message": f"Alert: {category} budget is at {ratio*100:.0f}% of monthly limit (₹{spent:.0f} / ₹{budget.allocated_amount:.0f})"
            })
            
    return alerts

# --- Google Places API / resolveMerchant ---

class ResolveMerchantRequest(BaseModel):
    merchant_name: str

@api_router.post("/resolve-merchant")
async def resolve_merchant_places(
    req: ResolveMerchantRequest,
    session: Session = Depends(get_session)
):
    clean = req.merchant_name.lower().strip()
    
    cached = session.exec(
        select(MerchantDictionary).where(MerchantDictionary.merchant_key == clean)
    ).first()
    if cached:
        return {"found": True, "category": cached.category, "merchant": req.merchant_name, "source": "dictionary"}

    if GOOGLE_PLACES_API_KEY:
        try:
            async with httpx.AsyncClient(timeout=4.0) as client:
                url = "https://places.googleapis.com/v1/places:searchText"
                headers = {
                    "Content-Type": "application/json",
                    "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY,
                    "X-Goog-FieldMask": "places.displayName,places.primaryType,places.types"
                }
                body = {"textQuery": req.merchant_name}
                resp = await client.post(url, headers=headers, json=body)
                if resp.status_code == 200:
                    data = resp.json()
                    places = data.get("places", [])
                    if places:
                        primary_type = places[0].get("primaryType", "")
                        types = places[0].get("types", [])
                        
                        mapped_category = None
                        all_types = [primary_type] + types
                        for t in all_types:
                            if any(k in t for k in ["restaurant", "cafe", "food", "bakery", "meal", "bar"]):
                                mapped_category = "Food & Dining"
                                break
                            elif any(k in t for k in ["store", "clothing", "electronics", "supermarket", "shopping"]):
                                mapped_category = "Shopping"
                                break
                            elif any(k in t for k in ["gas_station", "transit", "parking", "car", "taxi"]):
                                mapped_category = "Transportation"
                                break
                            elif any(k in t for k in ["hospital", "pharmacy", "doctor", "health", "gym"]):
                                mapped_category = "Healthcare"
                                break
                            elif any(k in t for k in ["movie_theater", "entertainment", "amusement"]):
                                mapped_category = "Entertainment"
                                break
                            elif any(k in t for k in ["real_estate", "lodging"]):
                                mapped_category = "Housing"
                                break
                            elif any(k in t for k in ["beauty", "spa", "hair_care", "salon"]):
                                mapped_category = "Personal"
                                break
                                
                        if mapped_category:
                            session.add(MerchantDictionary(merchant_key=clean, category=mapped_category, learned_from_user=False))
                            session.commit()
                            return {"found": True, "category": mapped_category, "merchant": req.merchant_name, "source": "google_places_api"}
        except Exception:
            pass

    places_lookup = {
        "naturals": "Personal",
        "jawed habib": "Personal",
        "enrich salon": "Personal",
        "cult.fit": "Personal",
        "gold's gym": "Personal",
        "dr. lal pathlabs": "Healthcare",
        "medplus": "Healthcare",
        "chaayos": "Food & Dining",
        "chai point": "Food & Dining",
        "third wave coffee": "Food & Dining",
        "blue tokai": "Food & Dining",
        "decathlon": "Shopping",
        "croma": "Shopping",
        "reliance digital": "Shopping",
        "vijay sales": "Shopping",
        "speedy auto": "Transportation",
        "fastag": "Transportation",
    }
    
    for key, cat in places_lookup.items():
        if key in clean or clean in key:
            session.add(MerchantDictionary(merchant_key=clean, category=cat, learned_from_user=False))
            session.commit()
            return {"found": True, "category": cat, "merchant": req.merchant_name, "source": "local_taxonomy"}
            
    return {"found": False, "category": None, "merchant": req.merchant_name}

# --- Merchant Dictionary Learning ---

class LearnDictionaryRequest(BaseModel):
    merchant_key: str
    category: str

@api_router.post("/dictionary/learn")
def learn_merchant_dictionary(
    req: LearnDictionaryRequest,
    session: Session = Depends(get_session)
):
    clean_key = req.merchant_key.strip().lower()
    existing = session.exec(
        select(MerchantDictionary).where(MerchantDictionary.merchant_key == clean_key)
    ).first()
    
    if existing:
        existing.category = req.category
        existing.learned_from_user = True
        existing.last_updated = datetime.now(timezone.utc)
        session.add(existing)
    else:
        session.add(MerchantDictionary(
            merchant_key=clean_key,
            category=req.category,
            learned_from_user=True,
            last_updated=datetime.now(timezone.utc)
        ))
    session.commit()
    return {"status": "learned", "merchant_key": clean_key, "category": req.category}

# --- Smart Capture ---

class NotificationParseRequest(BaseModel):
    raw_text: str
    source_app: Optional[str] = "notification"
    model: Optional[str] = None

@api_router.post("/capture/parse-notification")
async def parse_and_categorize_notification(
    req: NotificationParseRequest,
    session: Session = Depends(get_session)
):
    extracted = agent_coordinator.extract_from_notification_or_sms(req.raw_text)
    
    cat_result = await agent_coordinator.categorize_transaction(
        merchant_name=extracted["merchant"],
        amount=extracted["amount"],
        is_p2p=extracted["is_p2p"],
        session=session,
        model=req.model
    )
    
    transaction_created = None
    if not cat_result["needs_user_confirmation"] and extracted["amount"] > 0:
        new_tx = Transaction(
            title=f"{extracted['merchant']}",
            amount=extracted["amount"],
            merchant=extracted["merchant"],
            raw_text=req.raw_text,
            category=cat_result["category"],
            source=req.source_app or "notification",
            type="expense",
            date=extracted["date"],
            confidence=cat_result["confidence"],
            status="auto"
        )
        session.add(new_tx)
        session.commit()
        session.refresh(new_tx)
        transaction_created = new_tx
        
    return {
        "extracted": extracted,
        "categorization": cat_result,
        "auto_logged": transaction_created is not None,
        "transaction": transaction_created
    }

# --- Transactions Ledger (UUID Reconciliation) ---

@api_router.get("/transactions")
def list_transactions(session: Session = Depends(get_session)):
    statement = select(Transaction).order_by(Transaction.date.desc())
    return [t.model_dump() for t in session.exec(statement).all()]

@api_router.post("/transactions")
def create_or_upsert_transaction(tx: Transaction, session: Session = Depends(get_session)):
    # ID Reconciliation: Check if uuid already exists
    existing = session.exec(select(Transaction).where(Transaction.uuid == tx.uuid)).first()
    if existing:
        existing.title = tx.title
        existing.amount = tx.amount
        existing.merchant = tx.merchant
        existing.raw_text = tx.raw_text
        existing.category = tx.category
        existing.source = tx.source
        existing.type = tx.type
        existing.date = tx.date
        existing.confidence = tx.confidence
        existing.status = tx.status
        existing.notes = tx.notes
        existing.is_recurring = tx.is_recurring
        session.add(existing)
        session.commit()
        session.refresh(existing)
        tx = existing
    else:
        session.add(tx)
        session.commit()
        session.refresh(tx)
    
    # Auto-learn merchant mapping if confirmed
    if tx.status == "confirmed" and tx.merchant:
        clean_key = tx.merchant.strip().lower()
        dict_entry = session.exec(select(MerchantDictionary).where(MerchantDictionary.merchant_key == clean_key)).first()
        if dict_entry:
            dict_entry.category = tx.category
            dict_entry.learned_from_user = True
            session.add(dict_entry)
        else:
            session.add(MerchantDictionary(merchant_key=clean_key, category=tx.category, learned_from_user=True))
        session.commit()

    period = tx.date[:7] if tx.date and len(tx.date) >= 7 else date.today().strftime("%Y-%m")
    alerts = check_budget_alerts(tx.category, period, session) if tx.type == "expense" else []
    
    return {
        **tx.model_dump(),
        "alerts": alerts
    }

class UpdateTransactionByUuidRequest(BaseModel):
    title: Optional[str] = None
    amount: Optional[float] = None
    merchant: Optional[str] = None
    raw_text: Optional[str] = None
    category: Optional[str] = None
    source: Optional[str] = None
    type: Optional[str] = None
    date: Optional[str] = None
    confidence: Optional[float] = None
    status: Optional[str] = None
    notes: Optional[str] = None
    is_recurring: Optional[bool] = None

@api_router.put("/transactions/by-uuid/{uuid}")
def update_transaction_by_uuid(
    uuid: str,
    req: UpdateTransactionByUuidRequest,
    session: Session = Depends(get_session)
):
    tx = session.exec(select(Transaction).where(Transaction.uuid == uuid)).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")

    if req.title is not None: tx.title = req.title
    if req.amount is not None: tx.amount = req.amount
    if req.merchant is not None: tx.merchant = req.merchant
    if req.raw_text is not None: tx.raw_text = req.raw_text
    if req.category is not None: tx.category = req.category
    if req.source is not None: tx.source = req.source
    if req.type is not None: tx.type = req.type
    if req.date is not None: tx.date = req.date
    if req.confidence is not None: tx.confidence = req.confidence
    if req.status is not None: tx.status = req.status
    if req.notes is not None: tx.notes = req.notes
    if req.is_recurring is not None: tx.is_recurring = req.is_recurring
    
    session.add(tx)
    session.commit()
    session.refresh(tx)

    # Learn merchant mapping if confirmed
    if tx.status == "confirmed" and tx.merchant:
        clean_key = tx.merchant.strip().lower()
        dict_entry = session.exec(select(MerchantDictionary).where(MerchantDictionary.merchant_key == clean_key)).first()
        if dict_entry:
            dict_entry.category = tx.category
            dict_entry.learned_from_user = True
            session.add(dict_entry)
        else:
            session.add(MerchantDictionary(merchant_key=clean_key, category=tx.category, learned_from_user=True))
        session.commit()

    period = tx.date[:7] if tx.date and len(tx.date) >= 7 else date.today().strftime("%Y-%m")
    alerts = check_budget_alerts(tx.category, period, session) if tx.type == "expense" else []

    return {
        **tx.model_dump(),
        "alerts": alerts
    }

@api_router.delete("/transactions/{tx_id_or_uuid}")
def delete_transaction(tx_id_or_uuid: str, session: Session = Depends(get_session)):
    tx = None
    if tx_id_or_uuid.isdigit():
        tx = session.get(Transaction, int(tx_id_or_uuid))
    if not tx:
        tx = session.exec(select(Transaction).where(Transaction.uuid == tx_id_or_uuid)).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
            
    session.delete(tx)
    session.commit()
    return {"message": "Transaction deleted", "uuid": tx.uuid}

# --- Monthly Budgets & Rollover ---

@api_router.get("/budgets")
def list_budgets(
    period: Optional[str] = Query(None),
    session: Session = Depends(get_session)
):
    current_period = period or date.today().strftime("%Y-%m")
    budgets = session.exec(select(Budget).where(Budget.period == current_period)).all()
    
    # Rollover: if no budgets exist for requested period, copy from latest period
    if not budgets:
        all_periods = session.exec(select(Budget.period).distinct()).all()
        if all_periods:
            latest_period = sorted([p for p in all_periods if p is not None])[-1]
            latest_budgets = session.exec(select(Budget).where(Budget.period == latest_period)).all()
            for lb in latest_budgets:
                new_b = Budget(
                    category=lb.category,
                    allocated_amount=lb.allocated_amount,
                    spent_amount=0.0,
                    period=current_period
                )
                session.add(new_b)
            session.commit()
            budgets = session.exec(select(Budget).where(Budget.period == current_period)).all()
        else:
            default_categories = [
                ("Food & Dining", 12000.0),
                ("Housing", 18000.0),
                ("Transportation", 4500.0),
                ("Shopping", 5000.0),
                ("Bills & Utilities", 3500.0),
                ("Entertainment", 2000.0),
                ("Healthcare", 2000.0),
                ("Personal", 2000.0),
            ]
            for cat, amt in default_categories:
                session.add(Budget(category=cat, allocated_amount=amt, spent_amount=0.0, period=current_period))
            session.commit()
            budgets = session.exec(select(Budget).where(Budget.period == current_period)).all()
        
    # Dynamically compute spent_amount from transactions in this period
    all_txs = session.exec(select(Transaction).where(Transaction.type == "expense")).all()
    
    result = []
    for b in budgets:
        period_txs = [t for t in all_txs if t.category == b.category and t.date.startswith(b.period)]
        b.spent_amount = sum(t.amount for t in period_txs)
        session.add(b)
        result.append(b.model_dump())
        
    session.commit()
    return result

@api_router.post("/budgets")
def create_or_update_budget(b: Budget, session: Session = Depends(get_session)):
    current_period = b.period or date.today().strftime("%Y-%m")
    existing = session.exec(
        select(Budget).where(Budget.category == b.category, Budget.period == current_period)
    ).first()
    
    if existing:
        existing.allocated_amount = b.allocated_amount
        session.add(existing)
        session.commit()
        session.refresh(existing)
        return existing.model_dump()
        
    b.period = current_period
    session.add(b)
    session.commit()
    session.refresh(b)
    return b.model_dump()

# --- Savings Goals & checkGoalReallocation ---

@api_router.get("/goals")
def list_goals(session: Session = Depends(get_session)):
    return [g.model_dump() for g in session.exec(select(SavingsGoal)).all()]

@api_router.post("/goals")
def create_goal(goal: SavingsGoal, session: Session = Depends(get_session)):
    session.add(goal)
    session.commit()
    session.refresh(goal)
    return goal.model_dump()

@api_router.get("/goals/reallocation-plan")
async def get_weekly_reallocation_plan(
    model: Optional[str] = Query(None),
    session: Session = Depends(get_session)
):
    plan = await agent_coordinator.calculate_weekly_goal_reallocation(session=session, model=model)
    return plan

class ConfirmReallocationRequest(BaseModel):
    goal_id: int
    addition_amount: float
    category_adjustments: Dict[str, float]

@api_router.post("/goals/reallocation-plan/confirm")
def confirm_reallocation(
    req: ConfirmReallocationRequest,
    session: Session = Depends(get_session)
):
    goal = session.get(SavingsGoal, req.goal_id)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
        
    goal.current_progress += req.addition_amount
    session.add(goal)

    contribution = GoalContribution(
        goal_id=goal.id,
        amount=req.addition_amount,
        date=date.today().strftime("%Y-%m-%d"),
        source="reallocation",
        notes="virtual reallocation - no money is moved"
    )
    session.add(contribution)
    
    current_period = date.today().strftime("%Y-%m")
    for category, delta in req.category_adjustments.items():
        budget = session.exec(
            select(Budget).where(Budget.category == category, Budget.period == current_period)
        ).first()
        if not budget:
            budget = session.exec(select(Budget).where(Budget.category == category)).first()
        if budget:
            budget.allocated_amount = max(0.0, budget.allocated_amount + delta)
            session.add(budget)
            
    session.commit()
    return {
        "status": "confirmed",
        "goal_title": goal.title,
        "new_goal_progress": goal.current_progress,
        "adjustments_applied": req.category_adjustments,
        "disclaimer": "virtual reallocation - no money is moved"
    }

# --- Analytics Dashboard (Computed from Real Data) ---

@api_router.get("/analytics")
def get_analytics(session: Session = Depends(get_session)):
    transactions = session.exec(select(Transaction)).all()
    budgets = session.exec(select(Budget)).all()
    goals = session.exec(select(SavingsGoal)).all()
    
    total_income = sum(t.amount for t in transactions if t.type == "income")
    total_expense = sum(t.amount for t in transactions if t.type == "expense")
    net_savings = total_income - total_expense
    savings_rate = (net_savings / total_income * 100) if total_income > 0 else 0.0
    
    category_spend: Dict[str, float] = {}
    for t in transactions:
        if t.type == "expense":
            category_spend[t.category] = category_spend.get(t.category, 0.0) + t.amount
            
    needs_categories = {"Housing", "Bills & Utilities", "Food & Dining", "Groceries", "Healthcare", "Transportation"}
    needs_spent = sum(amt for cat, amt in category_spend.items() if cat in needs_categories)
    wants_spent = sum(amt for cat, amt in category_spend.items() if cat not in needs_categories)
    
    total_allocated = sum(b.allocated_amount for b in budgets)
    total_spent = sum(b.spent_amount for b in budgets)
    
    return {
        "currency": "INR",
        "summary": {
            "total_income": round(total_income, 2),
            "total_expense": round(total_expense, 2),
            "net_savings": round(net_savings, 2),
            "savings_rate_pct": round(savings_rate, 1),
            "total_budget_limit": round(total_allocated, 2),
            "total_budget_spent": round(total_spent, 2),
            "budget_health_pct": round((total_spent / total_allocated * 100), 1) if total_allocated > 0 else 0.0
        },
        "rule_50_30_20": {
            "needs": {
                "spent": round(needs_spent, 2),
                "actual_pct": round((needs_spent / total_income * 100), 1) if total_income > 0 else 0.0
            },
            "wants": {
                "spent": round(wants_spent, 2),
                "actual_pct": round((wants_spent / total_income * 100), 1) if total_income > 0 else 0.0
            },
            "savings": {
                "saved": round(net_savings, 2),
                "actual_pct": round(savings_rate, 1)
            }
        },
        "category_breakdown": [{"category": cat, "amount": round(amt, 2)} for cat, amt in category_spend.items()],
        "recent_transactions_count": len(transactions),
        "active_goals_count": len(goals)
    }

# --- Multi-Agent Chat ---

class AgentChatRequest(BaseModel):
    agent: str = "assistant"
    message: str
    model: Optional[str] = None

@api_router.post("/agent/chat")
async def chat_with_agent(req: AgentChatRequest, session: Session = Depends(get_session)):
    transactions = session.exec(select(Transaction).limit(25)).all()
    budgets = session.exec(select(Budget)).all()
    goals = session.exec(select(SavingsGoal)).all()
    
    financial_context = {
        "transactions": [{"merchant": t.merchant, "amount": t.amount, "category": t.category, "type": t.type, "date": t.date} for t in transactions],
        "budgets": [{"category": b.category, "allocated": b.allocated_amount, "spent": b.spent_amount} for b in budgets],
        "goals": [{"title": g.title, "target": g.target_amount, "progress": g.current_progress} for g in goals]
    }
    
    if req.agent == "auditor":
        agent_obj = agent_coordinator.auditor
    elif req.agent == "advisor":
        agent_obj = agent_coordinator.advisor
    elif req.agent == "strategist":
        agent_obj = agent_coordinator.strategist
    else:
        system_prompt = "You are FinTrack Assistant, an intelligent financial AI with full access to user's expense and budget ledger."
        agent_obj = agent_coordinator.auditor.__class__("assistant", "FinTrack Assistant", system_prompt)
        
    result = await agent_obj.execute(req.message, context=financial_context, model=req.model)
    return result

# Mount the protected /api router
app.include_router(api_router, prefix="/api")

# Note: Default uvicorn host is 127.0.0.1. Change to 0.0.0.0 or LAN IP only when testing on a physical mobile device.
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
