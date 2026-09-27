from datetime import datetime, date
from typing import Optional, List, Dict, Any
from sqlmodel import Field, SQLModel, create_engine, Session, select
import json

class Transaction(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str
    amount: float
    merchant: str
    raw_text: Optional[str] = None
    category: str # "Food & Dining", "Shopping", "Transportation", "Bills & Utilities", "Entertainment", "Healthcare", "Housing", "Income", "P2P Transfer", "Other"
    source: str = "merchant" # "merchant", "p2p", "sms", "notification", "manual"
    type: str = "expense" # "expense" or "income"
    date: str # YYYY-MM-DD
    confidence: float = 1.0 # 0.0 - 1.0
    status: str = "auto" # "auto", "confirmed", "skipped"
    notes: Optional[str] = None
    is_recurring: bool = False
    ai_flagged: bool = False
    ai_flag_reason: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

class MerchantDictionary(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    merchant_key: str = Field(unique=True, index=True) # Normalized merchant name
    category: str
    learned_from_user: bool = False
    last_updated: datetime = Field(default_factory=datetime.utcnow)

class Budget(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    category: str
    allocated_amount: float
    spent_amount: float = 0.0
    period: str = "2026-09" # YYYY-MM

class SavingsGoal(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str
    target_amount: float
    current_progress: float = 0.0
    target_date: str # YYYY-MM-DD
    category: str = "Gadgets" # "Safety", "Travel", "Gadgets", "Education", "General"
    status: str = "active" # "active", "achieved", "at_risk"
    monthly_target: float = 0.0
    created_at: datetime = Field(default_factory=datetime.utcnow)

class GoalMonthlyPlan(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    goal_id: int
    month: str # YYYY-MM
    target_savings: float
    actual_savings: float = 0.0
    category_adjustments_json: str = "{}" # JSON dict of proposed adjustments

class AgentMessage(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    agent_name: str # "auditor", "advisor", "strategist", "categorizer", "assistant"
    role: str # "user", "assistant", "system"
    content: str
    thought_trace: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

sqlite_file_name = "fintrack.db"
sqlite_url = f"sqlite:///{sqlite_file_name}"

engine = create_engine(sqlite_url, echo=False)

def init_db():
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        # Check if merchant dictionary is seeded
        existing_dict = session.exec(select(MerchantDictionary)).first()
        if not existing_dict:
            seed_merchant_dictionary(session)
            
        existing_tx = session.exec(select(Transaction)).first()
        if not existing_tx:
            seed_data(session)

def seed_merchant_dictionary(session: Session):
    """Seed comprehensive dictionary of popular Indian & Global merchants"""
    pre_seeded = [
        # Food & Dining
        ("swiggy", "Food & Dining"),
        ("zomato", "Food & Dining"),
        ("starbucks", "Food & Dining"),
        ("mcdonalds", "Food & Dining"),
        ("dominos", "Food & Dining"),
        ("kfc", "Food & Dining"),
        ("blinkit", "Food & Dining"),
        ("zepto", "Food & Dining"),
        ("instamart", "Food & Dining"),
        ("bigbasket", "Food & Dining"),
        ("whole foods", "Food & Dining"),
        ("trader joe's", "Food & Dining"),
        
        # Transportation & Fuel
        ("uber", "Transportation"),
        ("ola", "Transportation"),
        ("rapido", "Transportation"),
        ("namma yatri", "Transportation"),
        ("irctc", "Transportation"),
        ("shell", "Transportation"),
        ("hp petrol", "Transportation"),
        ("indian oil", "Transportation"),
        ("bharat petroleum", "Transportation"),
        
        # Shopping & E-commerce
        ("amazon", "Shopping"),
        ("flipkart", "Shopping"),
        ("myntra", "Shopping"),
        ("ajio", "Shopping"),
        ("nike", "Shopping"),
        ("zara", "Shopping"),
        ("h&m", "Shopping"),
        ("target", "Shopping"),
        
        # Bills & Utilities
        ("bescom", "Bills & Utilities"),
        ("airtel", "Bills & Utilities"),
        ("jio", "Bills & Utilities"),
        ("tata power", "Bills & Utilities"),
        ("act fibernet", "Bills & Utilities"),
        ("city utilities", "Bills & Utilities"),
        
        # Entertainment & Subscriptions
        ("netflix", "Entertainment"),
        ("spotify", "Entertainment"),
        ("youtube", "Entertainment"),
        ("prime video", "Entertainment"),
        ("bookmyshow", "Entertainment"),
        ("pvr cinemas", "Entertainment"),
        ("inox", "Entertainment"),
        
        # Healthcare
        ("apollo pharmacy", "Healthcare"),
        ("1mg", "Healthcare"),
        ("pharmeasy", "Healthcare"),
        ("practo", "Healthcare"),
        
        # Housing
        ("downtown realty", "Housing"),
        ("nobroker", "Housing"),
        ("society maintenance", "Housing"),
    ]
    for name, cat in pre_seeded:
        session.add(MerchantDictionary(merchant_key=name.lower(), category=cat, learned_from_user=False))
    session.commit()

def seed_data(session: Session):
    today = date.today().strftime("%Y-%m-%d")
    sample_transactions = [
        Transaction(title="Monthly Salary", amount=65000.00, merchant="Acme Corp", category="Income", type="income", date="2026-09-01", confidence=1.0, status="confirmed", source="manual"),
        Transaction(title="Apartment Rent", amount=18000.00, merchant="Downtown Realty", category="Housing", type="expense", date="2026-09-02", is_recurring=True, confidence=1.0, status="confirmed", source="notification"),
        Transaction(title="Electricity & Water", amount=2450.00, merchant="BESCOM", category="Bills & Utilities", type="expense", date="2026-09-05", confidence=1.0, status="auto", source="sms"),
        Transaction(title="Blinkit Quick Grocery", amount=1240.00, merchant="Blinkit", category="Food & Dining", type="expense", date="2026-09-08", confidence=1.0, status="auto", source="notification"),
        Transaction(title="Uber Commute to Office", amount=420.00, merchant="Uber", category="Transportation", type="expense", date="2026-09-10", confidence=1.0, status="auto", source="notification"),
        Transaction(title="Netflix & Spotify Subscriptions", amount=999.00, merchant="Netflix", category="Entertainment", type="expense", date="2026-09-12", is_recurring=True, confidence=1.0, status="auto", source="sms"),
        Transaction(title="Swiggy Dinner Delivery", amount=580.00, merchant="Swiggy", category="Food & Dining", type="expense", date="2026-09-15", confidence=1.0, status="auto", source="notification"),
        Transaction(title="Freelance Design Project", amount=15000.00, merchant="Client Upwork", category="Income", type="income", date="2026-09-16", confidence=1.0, status="confirmed", source="manual"),
        Transaction(title="Nike Running Shoes", amount=6499.00, merchant="Nike", category="Shopping", type="expense", date="2026-09-18", confidence=1.0, status="confirmed", source="notification", ai_flagged=True, ai_flag_reason="Discretionary spike in Shopping category"),
        Transaction(title="HP Petrol Station", amount=1500.00, merchant="HP Petrol", category="Transportation", type="expense", date="2026-09-20", confidence=1.0, status="auto", source="sms"),
        Transaction(title="Zomato Weekend Lunch", amount=890.00, merchant="Zomato", category="Food & Dining", type="expense", date="2026-09-22", confidence=1.0, status="auto", source="notification"),
        Transaction(title="UPI Transfer to Rahul", amount=1200.00, merchant="Rahul Sharma (9876543210)", category="P2P Transfer", type="expense", date=today, confidence=0.45, status="confirmed", source="notification", notes="Weekend Trip Split"),
    ]
    
    sample_budgets = [
        Budget(category="Food & Dining", allocated_amount=12000.00, spent_amount=2710.00, period="2026-09"),
        Budget(category="Housing", allocated_amount=18000.00, spent_amount=18000.00, period="2026-09"),
        Budget(category="Transportation", allocated_amount=4500.00, spent_amount=1920.00, period="2026-09"),
        Budget(category="Shopping", allocated_amount=8000.00, spent_amount=6499.00, period="2026-09"),
        Budget(category="Entertainment", allocated_amount=3000.00, spent_amount=999.00, period="2026-09"),
        Budget(category="Bills & Utilities", allocated_amount=3500.00, spent_amount=2450.00, period="2026-09"),
    ]
    
    sample_goals = [
        SavingsGoal(title="MacBook Pro M3 (Laptop)", target_amount=60000.00, current_progress=24000.00, target_date="2027-03-31", category="Gadgets", monthly_target=10000.00, status="active"),
        SavingsGoal(title="Emergency Safety Fund (6 Mo)", target_amount=150000.00, current_progress=95000.00, target_date="2027-09-30", category="Safety", monthly_target=12000.00, status="active"),
        SavingsGoal(title="Goa Trip with Friends", target_amount=25000.00, current_progress=18000.00, target_date="2026-12-15", category="Travel", monthly_target=3500.00, status="active"),
    ]

    for item in sample_transactions + sample_budgets + sample_goals:
        session.add(item)
    session.commit()

def get_session():
    with Session(engine) as session:
        yield session
