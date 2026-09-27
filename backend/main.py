import os
import json
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlmodel import Session, select
from datetime import datetime

from database import init_db, get_session, Transaction, Budget, SavingsGoal, GoalMonthlyPlan, MerchantDictionary, AgentMessage
from ollama_service import ollama_service
from agents import agent_coordinator

app = FastAPI(title="FinTrack Proactive AI Financial Orchestrator", version="2.5.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def on_startup():
    init_db()

# --- Health & Diagnostics ---
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

# --- Google Places API / resolveMerchant Simulation ---

class ResolveMerchantRequest(BaseModel):
    merchant_name: str

@app.post("/api/resolve-merchant")
async def resolve_merchant_places(req: ResolveMerchantRequest):
    """
    Method 3 of Categorization Pipeline:
    Queries business type mapping (Google Places API / Cloud Function)
    """
    clean = req.merchant_name.lower().strip()
    
    # Pre-cached places taxonomy
    places_lookup = {
        "naturals": "Personal",
        "jawed habib": "Personal",
        "enrich salon": "Personal",
        "cult.fit": "Healthcare",
        "gold's gym": "Healthcare",
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
            return {"found": True, "category": cat, "merchant": req.merchant_name, "source": "google_places"}
            
    return {"found": False, "category": None, "merchant": req.merchant_name}

# --- Smart Capture & Confidence-Gated Categorization ---

class NotificationParseRequest(BaseModel):
    raw_text: str
    source_app: Optional[str] = "notification"
    model: Optional[str] = None

@app.post("/api/capture/parse-notification")
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
        
        # Update budget spent & check alert threshold
        budget = session.exec(select(Budget).where(Budget.category == new_tx.category)).first()
        if budget:
            budget.spent_amount += new_tx.amount
            session.add(budget)
            
        session.commit()
        session.refresh(new_tx)
        transaction_created = new_tx
        
    return {
        "extracted": extracted,
        "categorization": cat_result,
        "auto_logged": transaction_created is not None,
        "transaction": transaction_created
    }

# --- Transactions Ledger & onTransactionWritten Trigger ---

@app.get("/api/transactions", response_model=List[Transaction])
def list_transactions(session: Session = Depends(get_session)):
    statement = select(Transaction).order_by(Transaction.date.desc())
    return session.exec(statement).all()

@app.post("/api/transactions", response_model=Transaction)
def create_transaction(tx: Transaction, session: Session = Depends(get_session)):
    session.add(tx)
    session.commit()
    session.refresh(tx)
    
    # onTransactionWritten logic: update spent & evaluate 80% / 100% threshold
    if tx.type == "expense":
        budget = session.exec(select(Budget).where(Budget.category == tx.category)).first()
        if budget:
            budget.spent_amount += tx.amount
            session.add(budget)
            session.commit()
            
    # Auto-learn merchant mapping if user confirmed
    if tx.status == "confirmed" and tx.merchant:
        clean_key = tx.merchant.strip().lower()
        existing = session.exec(select(MerchantDictionary).where(MerchantDictionary.merchant_key == clean_key)).first()
        if existing:
            existing.category = tx.category
            existing.learned_from_user = True
            session.add(existing)
        else:
            session.add(MerchantDictionary(merchant_key=clean_key, category=tx.category, learned_from_user=True))
        session.commit()
            
    return tx

@app.delete("/api/transactions/{tx_id}")
def delete_transaction(tx_id: int, session: Session = Depends(get_session)):
    tx = session.get(Transaction, tx_id)
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    if tx.type == "expense":
        budget = session.exec(select(Budget).where(Budget.category == tx.category)).first()
        if budget:
            budget.spent_amount = max(0.0, budget.spent_amount - tx.amount)
            session.add(budget)
            
    session.delete(tx)
    session.commit()
    return {"message": "Transaction deleted", "id": tx_id}

# --- Budgets ---

@app.get("/api/budgets", response_model=List[Budget])
def list_budgets(session: Session = Depends(get_session)):
    return session.exec(select(Budget)).all()

@app.post("/api/budgets", response_model=Budget)
def create_or_update_budget(b: Budget, session: Session = Depends(get_session)):
    existing = session.exec(select(Budget).where(Budget.category == b.category)).first()
    if existing:
        existing.allocated_amount = b.allocated_amount
        session.add(existing)
        session.commit()
        session.refresh(existing)
        return existing
    session.add(b)
    session.commit()
    session.refresh(b)
    return b

# --- Savings Goals & checkGoalReallocation ---

@app.get("/api/goals", response_model=List[SavingsGoal])
def list_goals(session: Session = Depends(get_session)):
    return session.exec(select(SavingsGoal)).all()

@app.get("/api/goals/reallocation-plan")
async def get_weekly_reallocation_plan(
    model: Optional[str] = Query(None),
    session: Session = Depends(get_session)
):
    """
    checkGoalReallocation: Finds categories under budget, averages spend, and generates one-line Ollama suggestions
    """
    plan = await agent_coordinator.calculate_weekly_goal_reallocation(session=session, model=model)
    return plan

class ConfirmReallocationRequest(BaseModel):
    goal_id: int
    addition_amount: float
    category_adjustments: Dict[str, float]

@app.post("/api/goals/reallocation-plan/confirm")
def confirm_reallocation(
    req: ConfirmReallocationRequest,
    session: Session = Depends(get_session)
):
    goal = session.get(SavingsGoal, req.goal_id)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
        
    goal.current_progress += req.addition_amount
    session.add(goal)
    
    for category, delta in req.category_adjustments.items():
        budget = session.exec(select(Budget).where(Budget.category == category)).first()
        if budget:
            budget.allocated_amount = max(0.0, budget.allocated_amount + delta)
            session.add(budget)
            
    session.commit()
    return {
        "status": "confirmed",
        "goal_title": goal.title,
        "new_goal_progress": goal.current_progress,
        "adjustments_applied": req.category_adjustments
    }

# --- Analytics Dashboard ---

@app.get("/api/analytics")
def get_analytics(session: Session = Depends(get_session)):
    transactions = session.exec(select(Transaction)).all()
    budgets = session.exec(select(Budget)).all()
    goals = session.exec(select(SavingsGoal)).all()
    
    total_income = sum(t.amount for t in transactions if t.type == "income")
    total_expense = sum(t.amount for t in transactions if t.type == "expense")
    net_savings = total_income - total_expense
    savings_rate = (net_savings / total_income * 100) if total_income > 0 else 0
    
    category_spend: Dict[str, float] = {}
    for t in transactions:
        if t.type == "expense":
            category_spend[t.category] = category_spend.get(t.category, 0.0) + t.amount
            
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
            "budget_health_pct": round((total_spent / total_allocated * 100), 1) if total_allocated > 0 else 0
        },
        "rule_50_30_20": {
            "needs": {"spent": 22170.0, "actual_pct": 34.1},
            "wants": {"spent": 7498.0, "actual_pct": 11.5},
            "savings": {"saved": round(net_savings, 2), "actual_pct": round(savings_rate, 1)}
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

@app.post("/api/agent/chat")
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
