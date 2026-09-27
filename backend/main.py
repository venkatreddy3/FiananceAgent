import os
import json
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlmodel import Session, select

from database import init_db, get_session, Transaction, Budget, SavingsGoal, AgentMessage
from ollama_service import ollama_service
from agents import agent_coordinator

app = FastAPI(title="FinTrack Multi-Agent API", version="1.0.0")

# Enable CORS for Flutter web / desktop / mobile
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
        "ollama_connected": ollama_ok,
        "available_models": models,
        "backend_version": "1.0.0"
    }

@app.get("/api/models")
async def get_models():
    models = await ollama_service.list_models()
    return {
        "models": models,
        "default": models[0] if models else "llama3.2",
        "ollama_available": len(models) > 0
    }

# --- Transactions ---
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
            budget.spent += tx.amount
            session.add(budget)
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
            budget.spent = max(0.0, budget.spent - tx.amount)
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
        existing.monthly_limit = b.monthly_limit
        session.add(existing)
        session.commit()
        session.refresh(existing)
        return existing
    session.add(b)
    session.commit()
    session.refresh(b)
    return b

# --- Savings Goals ---
@app.get("/api/goals", response_model=List[SavingsGoal])
def list_goals(session: Session = Depends(get_session)):
    return session.exec(select(SavingsGoal)).all()

@app.post("/api/goals", response_model=SavingsGoal)
def create_goal(g: SavingsGoal, session: Session = Depends(get_session)):
    session.add(g)
    session.commit()
    session.refresh(g)
    return g

# --- Financial Analytics Dashboard ---
@app.get("/api/analytics")
def get_analytics(session: Session = Depends(get_session)):
    transactions = session.exec(select(Transaction)).all()
    budgets = session.exec(select(Budget)).all()
    goals = session.exec(select(SavingsGoal)).all()
    
    total_income = sum(t.amount for t in transactions if t.type == "income")
    total_expense = sum(t.amount for t in transactions if t.type == "expense")
    net_savings = total_income - total_expense
    savings_rate = (net_savings / total_income * 100) if total_income > 0 else 0
    
    # Category Breakdown
    category_spend: Dict[str, float] = {}
    for t in transactions:
        if t.type == "expense":
            category_spend[t.category] = category_spend.get(t.category, 0.0) + t.amount
            
    # 50/30/20 rule classification
    needs_categories = {"Housing", "Utilities", "Transportation", "Food & Dining", "Healthcare"}
    wants_categories = {"Entertainment", "Shopping", "Other"}
    
    needs_spent = sum(amt for cat, amt in category_spend.items() if cat in needs_categories)
    wants_spent = sum(amt for cat, amt in category_spend.items() if cat in wants_categories)
    
    total_budget_limit = sum(b.monthly_limit for b in budgets)
    total_budget_spent = sum(b.spent for b in budgets)
    
    return {
        "summary": {
            "total_income": round(total_income, 2),
            "total_expense": round(total_expense, 2),
            "net_savings": round(net_savings, 2),
            "savings_rate_pct": round(savings_rate, 1),
            "total_budget_limit": round(total_budget_limit, 2),
            "total_budget_spent": round(total_budget_spent, 2),
            "budget_health_pct": round((total_budget_spent / total_budget_limit * 100), 1) if total_budget_limit > 0 else 0
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

# --- Multi-Agent AI Endpoints ---

class AgentChatRequest(BaseModel):
    agent: str = "assistant" # "auditor", "advisor", "strategist", "assistant"
    message: str
    model: Optional[str] = None

@app.post("/api/agent/chat")
async def chat_with_agent(req: AgentChatRequest, session: Session = Depends(get_session)):
    # Build context from current financial state
    transactions = session.exec(select(Transaction).limit(20)).all()
    budgets = session.exec(select(Budget)).all()
    goals = session.exec(select(SavingsGoal)).all()
    
    financial_context = {
        "recent_transactions": [{"title": t.title, "amount": t.amount, "category": t.category, "type": t.type, "date": t.date} for t in transactions],
        "budgets": [{"category": b.category, "limit": b.monthly_limit, "spent": b.spent} for b in budgets],
        "goals": [{"name": g.name, "target": g.target_amount, "current": g.current_amount} for g in goals]
    }
    
    if req.agent == "auditor":
        agent_obj = agent_coordinator.auditor
    elif req.agent == "advisor":
        agent_obj = agent_coordinator.advisor
    elif req.agent == "strategist":
        agent_obj = agent_coordinator.strategist
    else:
        system_prompt = "You are FinTrack Assistant, an intelligent financial AI with full access to user's expense and budget ledger. Answer queries accurately and constructively."
        agent_obj = agent_coordinator.auditor.__class__("assistant", "FinTrack Assistant", system_prompt)
        
    result = await agent_obj.execute(req.message, context=financial_context, model=req.model)
    return result

@app.post("/api/agent/audit")
async def trigger_full_audit(model: Optional[str] = Query(None), session: Session = Depends(get_session)):
    transactions = session.exec(select(Transaction)).all()
    budgets = session.exec(select(Budget)).all()
    goals = session.exec(select(SavingsGoal)).all()
    
    context = {
        "transactions": [t.dict() for t in transactions],
        "budgets": [b.dict() for b in budgets],
        "goals": [g.dict() for g in goals]
    }
    
    audit_results = await agent_coordinator.run_full_audit(context, model=model)
    return audit_results

class NLParseRequest(BaseModel):
    text: str
    model: Optional[str] = None

@app.post("/api/agent/parse-expense")
async def parse_expense_natural_language(req: NLParseRequest):
    parsed = await agent_coordinator.parse_natural_language_expense(req.text, model=req.model)
    return parsed

class ReceiptParseRequest(BaseModel):
    receipt_text: str
    model: Optional[str] = None

@app.post("/api/receipt/parse")
async def parse_receipt(req: ReceiptParseRequest):
    result = await agent_coordinator.parse_receipt_text(req.receipt_text, model=req.model)
    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
