from datetime import datetime, date
from typing import Optional, List
from sqlmodel import Field, SQLModel, create_engine, Session, select

class Transaction(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str
    amount: float
    category: str # "Food & Dining", "Housing", "Transportation", "Entertainment", "Healthcare", "Shopping", "Income", "Utilities", "Other"
    type: str # "expense" or "income"
    date: str # YYYY-MM-DD
    notes: Optional[str] = None
    merchant: Optional[str] = None
    is_recurring: bool = False
    ai_flagged: bool = False
    ai_flag_reason: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

class Budget(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    category: str
    monthly_limit: float
    spent: float = 0.0
    period: str = "2026-09" # YYYY-MM

class SavingsGoal(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    target_amount: float
    current_amount: float = 0.0
    target_date: str
    category: str = "General"

class AgentMessage(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    agent_name: str # "auditor", "advisor", "strategist", "assistant"
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
        # Check if transactions exist, if not, seed realistic data
        existing_tx = session.exec(select(Transaction)).first()
        if not existing_tx:
            seed_data(session)

def seed_data(session: Session):
    today = date.today().strftime("%Y-%m-%d")
    sample_transactions = [
        Transaction(title="Monthly Salary", amount=4500.00, category="Income", type="income", date="2026-09-01", merchant="Acme Corp"),
        Transaction(title="Apartment Rent", amount=1400.00, category="Housing", type="expense", date="2026-09-02", merchant="Downtown Realty", is_recurring=True),
        Transaction(title="Electricity & Water", amount=120.50, category="Utilities", type="expense", date="2026-09-05", merchant="City Utilities"),
        Transaction(title="Whole Foods Grocery", amount=165.30, category="Food & Dining", type="expense", date="2026-09-08", merchant="Whole Foods Market"),
        Transaction(title="Uber Commute", amount=24.80, category="Transportation", type="expense", date="2026-09-10", merchant="Uber"),
        Transaction(title="Netflix & Spotify Subscriptions", amount=32.98, category="Entertainment", type="expense", date="2026-09-12", merchant="Streaming Services", is_recurring=True),
        Transaction(title="Starbucks Coffee", amount=7.50, category="Food & Dining", type="expense", date="2026-09-15", merchant="Starbucks"),
        Transaction(title="Freelance Design Gig", amount=650.00, category="Income", type="income", date="2026-09-16", merchant="Client Upwork"),
        Transaction(title="Nike Running Shoes", amount=145.00, category="Shopping", type="expense", date="2026-09-18", merchant="Nike Store", ai_flagged=True, ai_flag_reason="Discretionary spike in Shopping category"),
        Transaction(title="Target Household Supplies", amount=89.20, category="Shopping", type="expense", date="2026-09-20", merchant="Target"),
        Transaction(title="Trader Joe's Groceries", amount=112.40, category="Food & Dining", type="expense", date="2026-09-22", merchant="Trader Joe's"),
        Transaction(title="Gas Station Fillup", amount=48.00, category="Transportation", type="expense", date="2026-09-24", merchant="Shell Gas"),
        Transaction(title="Dinner with Friends", amount=78.50, category="Food & Dining", type="expense", date=today, merchant="Bistro Bella"),
    ]
    
    sample_budgets = [
        Budget(category="Food & Dining", monthly_limit=600.00, spent=363.70, period="2026-09"),
        Budget(category="Housing", monthly_limit=1400.00, spent=1400.00, period="2026-09"),
        Budget(category="Transportation", monthly_limit=250.00, spent=72.80, period="2026-09"),
        Budget(category="Shopping", monthly_limit=300.00, spent=234.20, period="2026-09"),
        Budget(category="Entertainment", monthly_limit=150.00, spent=32.98, period="2026-09"),
        Budget(category="Utilities", monthly_limit=150.00, spent=120.50, period="2026-09"),
    ]
    
    sample_goals = [
        SavingsGoal(name="Emergency Fund (6 Months)", target_amount=15000.00, current_amount=9200.00, target_date="2027-06-30", category="Safety"),
        SavingsGoal(name="Japan Vacation 2027", target_amount=4000.00, current_amount=1850.00, target_date="2027-04-15", category="Travel"),
        SavingsGoal(name="New MacBook Pro", target_amount=2500.00, current_amount=1600.00, target_date="2026-12-31", category="Gadgets"),
    ]

    for item in sample_transactions + sample_budgets + sample_goals:
        session.add(item)
    session.commit()

def get_session():
    with Session(engine) as session:
        yield session
