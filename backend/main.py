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

app = FastAPI(title="FinTrack Proactive AI Financial Orchestrator", version="2.0.0")

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

# --- Health & Models ---
@app.get("/api/health")
async def health_check():
    ollama_ok = await ollama_service.is_available()
    models = await ollama_service.list_models() if ollama_ok else []
    return {
        "status": "healthy",
        "service": "FinTrack Agent Hub",
        "ollama_connected": ollama_ok,
        "available_models": models,
        "version": "2.0.0"
    }

@app.get("/api/models")
async def get_models():
    models = await ollama_service.list_models()
    return {
        "models": models,
        "default": models[0] if models else "llama3.2",
        "ollama_available": len(models) > 0
    }

# --- Smart Capture & Confidence-Gated Categorization ---

class NotificationParseRequest(BaseModel):
    raw_text: str
    source_app: Optional[str] = "notification" # "PhonePe", "Google Pay", "Paytm", "SMS", etc.
    model: Optional[str] = None

@app.post("/api/capture/parse-notification")
async def parse_and_categorize_notification(
    req: NotificationParseRequest,
    session: Session = Depends(get_session)
):
    """
    Core Pipeline (Section 3 of Technical Spec):
    1. Parse raw notification / SMS via regex
    2. Run confidence-gated categorizer (dictionary -> learned -> Ollama)
    3. Route to Auto-Tag vs Categorize Bottom-Sheet
    """
    extracted = agent_coordinator.extract_from_notification_or_sms(req.raw_text)
    
    cat_result = await agent_coordinator.categorize_transaction(
        merchant_name=extracted["merchant"],
        amount=extracted["amount"],
        is_p2p=extracted["is_p2p"],
        session=session,
        model=req.model
    )
    
    # Check if we should automatically persist high confidence transactions
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
        
        # Update budget spent
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

# --- Merchant Dictionary Learning ---

class MerchantLearnRequest(BaseModel):
    merchant_key: str
    category: str

@app.post("/api/dictionary/learn")
def learn_merchant_mapping(
    req: MerchantLearnRequest,
    session: Session = Depends(get_session)
):
    """Saves user confirmation from Bottom-Sheet back into Merchant Dictionary"""
    clean_key = req.merchant_key.strip().lower()
    existing = session.exec(
        select(MerchantDictionary).where(MerchantDictionary.merchant_key == clean_key)
    ).first()
    
    if existing:
        existing.category = req.category
        existing.learned_from_user = True
        existing.last_updated = datetime.utcnow()
        session.add(existing)
    else:
        new_entry = MerchantDictionary(
            merchant_key=clean_key,
            category=req.category,
            learned_from_user=True
        )
        session.add(new_entry)
        
    session.commit()
    return {"status": "success", "merchant_key": clean_key, "category": req.category}

@app.get("/api/dictionary", response_model=List[MerchantDictionary])
def list_dictionary(session: Session = Depends(get_session)):
    return session.exec(select(MerchantDictionary)).all()

# --- Transactions Ledger ---

@app.get("/api/transactions", response_model=List[Transaction])
def list_transactions(session: Session = Depends(get_session)):
    statement = select(Transaction).order_by(Transaction.date.desc())
    return session.exec(statement).all()

@app.post("/api/transactions", response_model=Transaction)
def create_transaction(tx: Transaction, session: Session = Depends(get_session)):
    session.add(tx)
    session.commit()
    session.refresh(tx)
    
    # Update budget spent if it's an expense
    if tx.type == "expense":
        budget = session.exec(select(Budget).where(Budget.category == tx.category)).first()
        if budget:
            budget.spent_amount += tx.amount
            session.add(budget)
            session.commit()
            
    # Auto-learn merchant mapping if confirmed by user
    if tx.status == "confirmed" and tx.merchant:
        learn_merchant_mapping(
            MerchantLearnRequest(merchant_key=tx.merchant, category=tx.category),
            session
        )
            
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

# --- Savings Goals & Dynamic Reallocation ---

@app.get("/api/goals", response_model=List[SavingsGoal])
def list_goals(session: Session = Depends(get_session)):
    return session.exec(select(SavingsGoal)).all()

@app.post("/api/goals", response_model=SavingsGoal)
def create_goal(g: SavingsGoal, session: Session = Depends(get_session)):
    session.add(g)
    session.commit()
    session.refresh(g)
    return g

@app.get("/api/goals/reallocation-plan")
async def get_weekly_reallocation_plan(
    model: Optional[str] = Query(None),
    session: Session = Depends(get_session)
):
    """
    Weekly Re-planning & Slack Detection Endpoint (Section 5 of Spec)
    """
    plan = await agent_coordinator.calculate_weekly_goal_reallocation(session=session, model=model)
    return plan

class ConfirmReallocationRequest(BaseModel):
    goal_id: int
    addition_amount: float
    category_adjustments: Dict[str, float] # e.g. {"Entertainment": -500.0, "Shopping": -300.0}

@app.post("/api/goals/reallocation-plan/confirm")
def confirm_reallocation(
    req: ConfirmReallocationRequest,
    session: Session = Depends(get_session)
):
    """
    Safety Gate: 1-Tap User Confirmation that virtually updates in-app budget caps
    """
    goal = session.get(SavingsGoal, req.goal_id)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
        
    goal.current_progress += req.addition_amount
    session.add(goal)
    
    # Adjust in-app budget allocations
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
            
    needs_categories = {"Housing", "Bills & Utilities", "Transportation", "Food & Dining", "Healthcare"}
    wants_categories = {"Entertainment", "Shopping", "P2P Transfer", "Other"}
    
    needs_spent = sum(amt for cat, amt in category_spend.items() if cat in needs_categories)
    wants_spent = sum(amt for cat, amt in category_spend.items() if cat in wants_categories)
    
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
            "needs": {
                "spent": round(needs_spent, 2),
                "target_50_pct": round(total_income * 0.50, 2),
                "actual_pct": round((needs_spent / total_income * 100), 1) if total_income > 0 else 0
            },
            "wants": {
                "spent": round(wants_spent, 2),
                "target_30_pct": round(total_income * 0.30, 2),
                "actual_pct": round((wants_spent / total_income * 100), 1) if total_income > 0 else 0
            },
            "savings": {
                "saved": round(net_savings, 2),
                "target_20_pct": round(total_income * 0.20, 2),
                "actual_pct": round(savings_rate, 1)
            }
        },
        "category_breakdown": [{"category": cat, "amount": round(amt, 2)} for cat, amt in category_spend.items()],
        "recent_transactions_count": len(transactions),
        "active_goals_count": len(goals)
    }

# --- Multi-Agent Chat Hub ---

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
        system_prompt = "You are FinTrack Proactive AI Assistant. Help the user optimize budgets, hit savings goals, and understand their expenses."
        agent_obj = agent_coordinator.auditor.__class__("assistant", "FinTrack Assistant", system_prompt)
        
    result = await agent_obj.execute(req.message, context=financial_context, model=req.model)
    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
