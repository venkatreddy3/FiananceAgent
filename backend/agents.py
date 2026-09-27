import json
import re
from datetime import datetime, date
import calendar
from typing import Dict, Any, List, Optional, Tuple
from ollama_service import ollama_service
from sqlmodel import Session, select
from database import MerchantDictionary, Budget, SavingsGoal, Transaction, GoalContribution

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

# --- Prompts ---

AUDITOR_PROMPT = """You are the 'FinTrack Forensic Expense Auditor Agent'.
Analyze the user's Indian UPI and card transactions:
1. Detect spending spikes, recurring leakage, or unexpected category surges.
2. Flag discretionary vs essential spending proportions.
3. Highlight high-burn days and provide 3 crisp forensic recommendations with emoji badges."""

BUDGET_PROMPT = """You are the 'FinTrack Budget Advisor Agent' enforcing the 50/30/20 rule and category burn rates.
1. Classify spend into Needs (50%), Wants (30%), and Savings (20%).
2. Track remaining daily allowance for the current month.
3. Highlight any category pacing over 100% of expected burn velocity."""

STRATEGIST_PROMPT = """You are the 'FinTrack Wealth & Goal Strategist Agent'.
Your goal is to accelerate the user's financial goals (e.g. Laptop, Emergency Fund, Travel):
1. Review active goals, monthly targets, and current savings velocity.
2. Advise on surplus reallocation and milestone projections."""

CATEGORIZATION_PROMPT = """You are the 'FinTrack Merchant Categorizer LLM'.
Given an unrecognized Indian or international merchant / payment payee name, classify it into EXACTLY ONE of these canonical categories:
- Food & Dining
- Shopping
- Transportation
- Bills & Utilities
- Entertainment
- Healthcare
- Housing
- Personal
- P2P Transfer
- Other

Output ONLY valid JSON matching this exact schema:
{
  "category": "One of the above categories",
  "confidence": 0.90,
  "rationale": "Brief reason"
}
Confidence must be a float between 0.00 and 1.00."""

INSIGHT_SYNTHESIZER_PROMPT = """You are the 'FinTrack Insight Phraser'.
Translate deterministic financial numbers, slack calculations, and proposed budget shifts into a concise, motivating 2-sentence notification for the user.
Note that this is a virtual reallocation - no money is moved.
Keep it crystal clear, positive, and actionable."""

class MultiAgentCoordinator:
    def __init__(self):
        self.auditor = BaseAgent("auditor", "Forensic Expense Auditor", AUDITOR_PROMPT)
        self.advisor = BaseAgent("advisor", "Budget Advisor", BUDGET_PROMPT)
        self.strategist = BaseAgent("strategist", "Savings Strategist", STRATEGIST_PROMPT)
        self.categorizer = BaseAgent("categorizer", "Merchant Categorizer", CATEGORIZATION_PROMPT)
        self.insight_phraser = BaseAgent("phraser", "Insight Phraser", INSIGHT_SYNTHESIZER_PROMPT)

    def extract_from_notification_or_sms(self, text: str) -> Dict[str, Any]:
        """
        Deterministic Regex Extractor for PhonePe, Google Pay, Paytm, and Indian Bank SMS
        """
        amount = 0.0
        amt_match = re.search(r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)', text, re.IGNORECASE)
        if amt_match:
            amount_str = amt_match.group(1).replace(',', '')
            try:
                amount = float(amount_str)
            except ValueError:
                amount = 0.0
        
        merchant = "Unknown Payee"
        is_p2p = False
        
        p2p_match = re.search(r'(?:paid to|sent to|transferred to|transfer to|to)\s+([A-Za-z0-9\s@\._\-]+?)(?:\s+(?:on|ref|upi|using|from|via|\.)|$)', text, re.IGNORECASE)
        vpa_match = re.search(r'([a-zA-Z0-9\.\-_]+@(okaxis|okhdfcbank|okicici|oksbi|paytm|ybl|axl|ibl|upi))', text, re.IGNORECASE)
        phone_match = re.search(r'\b(?:[6-9]\d{9})\b', text)
        
        merchant_match = re.search(r'(?:at|spent on|info\s*:\s*|towards)\s+([A-Za-z0-9\s&\.\'\-]+?)(?:\s+(?:on|ref|avl|bal|using|from|via|\.)|$)', text, re.IGNORECASE)
        
        if merchant_match:
            merchant = merchant_match.group(1).strip()
        elif p2p_match:
            merchant = p2p_match.group(1).strip()
            is_p2p = True
        elif vpa_match:
            merchant = vpa_match.group(1).strip()
            is_p2p = True
        elif phone_match:
            merchant = f"Contact ({phone_match.group(0)})"
            is_p2p = True
            
        return {
            "amount": amount,
            "merchant": merchant,
            "is_p2p": is_p2p or bool(phone_match or vpa_match),
            "raw_text": text,
            "date": date.today().strftime("%Y-%m-%d")
        }

    async def categorize_transaction(
        self,
        merchant_name: str,
        amount: float,
        is_p2p: bool,
        session: Session,
        model: Optional[str] = None
    ) -> Dict[str, Any]:
        clean_merchant = merchant_name.strip().lower()
        
        if is_p2p:
            return {
                "category": "P2P Transfer",
                "confidence": 0.40,
                "needs_user_confirmation": True,
                "source": "p2p_detection",
                "matched_key": clean_merchant
            }
            
        # Step 1: Exact match in MerchantDictionary
        dict_entry = session.exec(
            select(MerchantDictionary).where(MerchantDictionary.merchant_key == clean_merchant)
        ).first()
        
        if not dict_entry:
            # Step 2: Whole-word match in dictionary on merchant name
            all_dict = session.exec(select(MerchantDictionary)).all()
            for entry in all_dict:
                pattern = re.compile(rf'\b{re.escape(entry.merchant_key)}\b', re.IGNORECASE)
                if pattern.search(clean_merchant):
                    dict_entry = entry
                    break

        if dict_entry:
            conf = 0.95 if dict_entry.learned_from_user else 1.0
            return {
                "category": dict_entry.category,
                "confidence": conf,
                "needs_user_confirmation": False,
                "source": "dictionary" if not dict_entry.learned_from_user else "learned_history",
                "matched_key": dict_entry.merchant_key
            }

        # Step 3: Ollama LLM Fallback
        prompt = f"Merchant / Payee: '{merchant_name}'\nAmount: INR {amount}"
        res = await ollama_service.generate_response(
            prompt=prompt,
            system_prompt=CATEGORIZATION_PROMPT,
            model=model,
            format_json=True
        )
        
        try:
            match = re.search(r'\{.*\}', res["response"], re.DOTALL)
            parsed = json.loads(match.group(0) if match else res["response"])
            cat = parsed.get("category", "Other")
            conf = float(parsed.get("confidence", 0.70))
            
            needs_confirm = conf < 0.85
            return {
                "category": cat,
                "confidence": conf,
                "needs_user_confirmation": needs_confirm,
                "source": "ollama_llm",
                "matched_key": clean_merchant
            }
        except Exception:
            return {
                "category": "Shopping" if amount > 500 else "Food & Dining",
                "confidence": 0.60,
                "needs_user_confirmation": True,
                "source": "heuristic_fallback",
                "matched_key": clean_merchant
            }

    async def calculate_weekly_goal_reallocation(
        self,
        session: Session,
        model: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Weekly Re-planning Loop & Slack Detection:
        - Evaluates all active goals sorted by nearest deadline first
        - Applies cuts ONLY to current month's budget
        - Virtual reallocation copy: 'virtual reallocation - no money is moved'
        """
        today = date.today()
        current_period = today.strftime("%Y-%m")
        _, days_in_month = calendar.monthrange(today.year, today.month)
        day_of_month = today.day
        month_progress_ratio = day_of_month / days_in_month
        
        budgets = session.exec(select(Budget).where(Budget.period == current_period)).all()
        if not budgets:
            budgets = session.exec(select(Budget)).all()
            
        # Active goals sorted by nearest target date
        goals = session.exec(
            select(SavingsGoal)
            .where(SavingsGoal.status == "active")
            .order_by(SavingsGoal.target_date.asc())
        ).all()
        
        essential_categories = {"Housing", "Bills & Utilities", "Healthcare", "Groceries"}
        
        category_slack: Dict[str, float] = {}
        total_slack = 0.0
        
        for b in budgets:
            if b.category not in essential_categories:
                expected_spend = b.allocated_amount * month_progress_ratio
                slack = expected_spend - b.spent_amount
                if slack > 100: # Only count meaningful surplus
                    category_slack[b.category] = round(slack, 2)
                    total_slack += slack

        reallocations = []
        if total_slack > 0 and goals:
            # Prioritize nearest active goal
            primary_goal = goals[0]
            shift_amount = round(total_slack * 0.70, 2)
            
            adjustments = {}
            for cat, sl in category_slack.items():
                cat_shift = round(sl * 0.70, 2)
                adjustments[cat] = -cat_shift
            
            reallocations.append({
                "goal_id": primary_goal.id,
                "goal_title": primary_goal.title,
                "proposed_addition": shift_amount,
                "source_slack_breakdown": category_slack,
                "category_adjustments": adjustments,
                "disclaimer": "virtual reallocation - no money is moved"
            })

        synthesis_prompt = (
            f"Month: {today.strftime('%B %Y')} (Day {day_of_month}/{days_in_month}).\n"
            f"Identified Discretionary Category Slack: {json.dumps(category_slack)}.\n"
            f"Total Slack Available: INR {round(total_slack, 2)}.\n"
            f"Proposed Goal Reallocations: {json.dumps(reallocations)}.\n"
            f"Note: This is a virtual reallocation - no money is moved.\n"
            f"Synthesize a crisp, encouraging 2-sentence proactive alert for the user explaining the benefit."
        )
        
        phrased_insight = await self.insight_phraser.execute(synthesis_prompt, model=model)
        
        return {
            "date": today.isoformat(),
            "day_of_month": day_of_month,
            "days_in_month": days_in_month,
            "month_progress_pct": round(month_progress_ratio * 100, 1),
            "total_discretionary_slack": round(total_slack, 2),
            "category_slack": category_slack,
            "proposed_reallocations": reallocations,
            "disclaimer": "virtual reallocation - no money is moved",
            "agent_message": phrased_insight["response"],
            "requires_user_confirmation": len(reallocations) > 0
        }

agent_coordinator = MultiAgentCoordinator()
