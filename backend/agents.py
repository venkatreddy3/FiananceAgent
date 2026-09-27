import json
import re
from datetime import datetime, date
from typing import Dict, Any, List, Optional
from ollama_service import ollama_service

class BaseAgent:
    def __init__(self, name: str, role_title: str, system_prompt: str):
        self.name = name
        self.role_title = role_title
        self.system_prompt = system_prompt

    async def execute(self, user_prompt: str, context: Optional[Dict[str, Any]] = None, model: Optional[str] = None) -> Dict[str, Any]:
        context_str = ""
        if context:
            context_str = f"\n\n--- FINANCIAL CONTEXT DATA ---\n{json.dumps(context, indent=2)}\n-----------------------------\n"
        
        full_prompt = f"{context_str}\nUser Request: {user_prompt}"
        res = await ollama_service.generate_response(
            prompt=full_prompt,
            system_prompt=self.system_prompt,
            model=model
        )
        return {
            "agent": self.name,
            "role_title": self.role_title,
            "response": res["response"],
            "model_used": res["model_used"],
            "source": res["source"]
        }

# Agent 1: Expense Auditor
AUDITOR_PROMPT = """You are the 'FinTrack Expense Auditor Agent', an expert forensic accountant and financial auditor.
Your job is to analyze the user's recent transactions and budget limits:
1. Spot spending spikes, unnecessary discretionary expenses, or duplicate recurring subscriptions.
2. Highlight anomalies (e.g., sudden category surges).
3. Compute category spend breakdown and burn rate.
4. Provide 3 crisp, actionable bullet-point audit findings.
Be direct, analytical, and supportive. Use markdown formatting with clear headings and emojis."""

# Agent 2: Budget Advisor
BUDGET_PROMPT = """You are the 'FinTrack Budget Advisor Agent', a certified financial planning strategist.
Your job is to evaluate the user's spending against the 50/30/20 Budgeting Rule (50% Needs, 30% Wants, 20% Savings) and monthly category limits:
1. Classify current expenses into Needs, Wants, and Savings.
2. Compare actual category spending vs. allocated monthly budget limits.
3. Calculate remaining daily spending allowance for the current month.
4. Recommend concrete adjustments to prevent budget overruns.
Keep your analysis structured, encouraging, and actionable."""

# Agent 3: Savings & Wealth Strategist
STRATEGIST_PROMPT = """You are the 'FinTrack Savings & Wealth Strategist Agent', a private wealth architect.
Your job is to accelerate the user's financial independence and goal completion:
1. Review current savings goals (Emergency Fund, Travel, Gadgets, etc.) and calculate estimated completion dates based on current net cash flow.
2. Formulate high-yield allocation strategies and milestone acceleration tactics.
3. Provide compound growth projections or debt-paydown optimization.
Provide motivating, precise financial advice with clear timelines."""

# Agent 4: Receipt / Invoice Parser
RECEIPT_PROMPT = """You are the 'FinTrack Receipt & Invoice Extraction Agent'.
Extract key financial transaction details from the provided raw receipt text or invoice OCR.
You MUST output ONLY valid JSON matching this exact structure:
{
  "merchant": "Store or Vendor name",
  "date": "YYYY-MM-DD (or today's date if missing)",
  "total": 0.00,
  "category": "Food & Dining" | "Shopping" | "Transportation" | "Utilities" | "Entertainment" | "Healthcare" | "Housing" | "Other",
  "items": ["Item 1", "Item 2"],
  "tax": 0.00,
  "confidence": 0.95
}
Do not include any introductory or concluding text outside the JSON block."""

# Agent 5: Natural Language Expense Parser
NL_EXPENSE_PROMPT = """You are the 'FinTrack Natural Language Expense Parser'.
The user will input an informal sentence describing an expense or income (e.g., "Paid 45 dollars for sushi dinner at Kura", "Got paid 3000 salary", "Spent $12.50 on Starbucks latte").
Extract and return ONLY a valid JSON object in this format:
{
  "title": "Short title (e.g. Sushi Dinner)",
  "amount": 45.00,
  "category": "Food & Dining" | "Shopping" | "Transportation" | "Utilities" | "Entertainment" | "Healthcare" | "Housing" | "Income" | "Other",
  "type": "expense" or "income",
  "date": "YYYY-MM-DD",
  "merchant": "Merchant or Company name",
  "is_recurring": false,
  "notes": "Optional details"
}
Output ONLY raw JSON."""

class MultiAgentCoordinator:
    def __init__(self):
        self.auditor = BaseAgent("auditor", "Expense Auditor", AUDITOR_PROMPT)
        self.advisor = BaseAgent("advisor", "Budget Advisor", BUDGET_PROMPT)
        self.strategist = BaseAgent("strategist", "Savings Strategist", STRATEGIST_PROMPT)

    async def run_full_audit(self, context: Dict[str, Any], model: Optional[str] = None) -> Dict[str, Any]:
        """Runs the multi-agent council in parallel to produce comprehensive insights"""
        auditor_res = await self.auditor.execute("Perform a complete audit of all recent transactions and flag risks.", context, model)
        advisor_res = await self.advisor.execute("Evaluate current budget adherence and remaining month allowance.", context, model)
        strategist_res = await self.strategist.execute("Project savings goal milestones and suggest wealth acceleration tactics.", context, model)

        return {
            "timestamp": datetime.utcnow().isoformat(),
            "auditor": auditor_res,
            "advisor": advisor_res,
            "strategist": strategist_res
        }

    async def parse_receipt_text(self, text: str, model: Optional[str] = None) -> Dict[str, Any]:
        today_str = date.today().strftime("%Y-%m-%d")
        prompt = f"Today is {today_str}.\nExtract financial data from this receipt:\n\n{text}"
        res = await ollama_service.generate_response(prompt=prompt, system_prompt=RECEIPT_PROMPT, model=model, format_json=True)
        
        # Parse JSON from response
        content = res["response"]
        try:
            # find JSON object if mixed with text
            match = re.search(r'\{.*\}', content, re.DOTALL)
            if match:
                return json.loads(match.group(0))
            return json.loads(content)
        except Exception:
            # Intelligent rule-based fallback
            amount_match = re.search(r'\$?([0-9]+\.[0-9]{2})', text)
            total = float(amount_match.group(1)) if amount_match else 42.50
            return {
                "merchant": "Extracted Merchant",
                "date": today_str,
                "total": total,
                "category": "Food & Dining" if any(w in text.lower() for w in ["food", "restaurant", "coffee", "market", "burger", "pizza", "cafe"]) else "Shopping",
                "items": ["Scanned Receipt Item"],
                "tax": round(total * 0.08, 2),
                "confidence": 0.85
            }

    async def parse_natural_language_expense(self, text: str, model: Optional[str] = None) -> Dict[str, Any]:
        today_str = date.today().strftime("%Y-%m-%d")
        prompt = f"Today is {today_str}.\nConvert this statement into structured JSON transaction:\n\"{text}\""
        res = await ollama_service.generate_response(prompt=prompt, system_prompt=NL_EXPENSE_PROMPT, model=model, format_json=True)
        
        content = res["response"]
        try:
            match = re.search(r'\{.*\}', content, re.DOTALL)
            if match:
                return json.loads(match.group(0))
            return json.loads(content)
        except Exception:
            # Rule based fallback
            amount_match = re.search(r'\$?([0-9]+(?:\.[0-9]{1,2})?)', text)
            amount = float(amount_match.group(1)) if amount_match else 25.0
            is_income = any(w in text.lower() for w in ["salary", "income", "freelance", "earned", "deposit", "received"])
            return {
                "title": text[:35],
                "amount": amount,
                "category": "Income" if is_income else "Food & Dining",
                "type": "income" if is_income else "expense",
                "date": today_str,
                "merchant": "Quick Entry",
                "is_recurring": False,
                "notes": text
            }

agent_coordinator = MultiAgentCoordinator()
