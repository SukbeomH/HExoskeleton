import unittest
from unittest.mock import patch, mock_open, MagicMock
from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.types import Command
from langgraph.graph import END

from langchain_tools.agent.graph.host import supervisor_node, guardian_node
from langchain_tools.agent.graph.state import AgentState

class TestAgentHost(unittest.TestCase):

    @patch("builtins.open", new_callable=mock_open)
    def test_supervisor_captures_intent(self, mock_file):
        """Test initial Intent Capture logic"""
        # Given: No intent_path in state
        state: AgentState = {
            "messages": [HumanMessage(content="Build a login page")],
            "intent_path": None,
            "plan_path": None,
            "changed_files": []
        }

        # When: Supervisor runs
        cmd = supervisor_node(state)

        # Then: INTENT.md should be written and route to architect
        mock_file.assert_called_with("INTENT.md", "w")
        self.assertIsInstance(cmd, Command)
        self.assertEqual(cmd.goto, "architect")
        self.assertEqual(cmd.update["intent_path"], "INTENT.md")

    def test_supervisor_routes_to_artisan_when_plan_exists(self):
        """Test routing to Artisan when Plan exists but Code doesn't"""
        state: AgentState = {
            "messages": [SystemMessage(content="Plan created.")],
            "intent_path": "INTENT.md",
            "plan_path": "PLAN.md",
            "changed_files": []
        }

        cmd = supervisor_node(state)

        self.assertEqual(cmd.goto, "artisan")

    def test_supervisor_routes_to_guardian_when_code_exists(self):
        """Test routing to Guardian when Code exists"""
        state: AgentState = {
            "messages": [SystemMessage(content="Code implemented.")],
            "intent_path": "INTENT.md",
            "plan_path": "PLAN.md",
            "changed_files": ["src/main.py"]
        }

        cmd = supervisor_node(state)

        self.assertEqual(cmd.goto, "guardian")

    @patch("langchain_tools.agent.graph.experts.guardian.SecurityAuditTool")
    @patch("langchain_tools.agent.graph.experts.guardian.AutoVerifyTool")
    @patch("builtins.open", new_callable=mock_open, read_data="# Intent Content")
    def test_guardian_verifies_intent(self, mock_file, MockAutoVerify, MockSecurityAudit):
        """Test Guardian verifies against INTENT.md"""
        # Given
        state: AgentState = {
            "messages": [],
            "intent_path": "INTENT.md",
            "changed_files": ["src/main.py"]
        }

        # Mock Tools Success
        mock_av_instance = MockAutoVerify.return_value
        mock_av_instance.invoke.return_value = {"status": "passed"}

        mock_sa_instance = MockSecurityAudit.return_value
        mock_sa_instance.invoke.return_value = {"status": "secure"}

        # Capture stdout to verify mock print
        with patch("sys.stdout", new=MagicMock()) as mock_stdout:
            cmd = guardian_node(state)

        mock_file.assert_called_with("INTENT.md", "r")
        self.assertEqual(cmd.goto, "librarian")
        # In actual code, we used print for mock verification result.
        # Ideally we check logs or callback, but for now checking flow logic is enough.

if __name__ == "__main__":
    unittest.main()
