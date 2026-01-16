import unittest
from unittest.mock import patch, MagicMock
from langchain_core.messages import SystemMessage
from langgraph.types import Command
from langgraph.graph import END

from langchain_tools.agent.graph.experts.librarian import librarian_node
from langchain_tools.agent.graph.state import AgentState

class TestLibrarian(unittest.TestCase):

    @patch("langchain_tools.agent.graph.experts.librarian.ClaudeKnowledgeUpdaterTool")
    def test_librarian_updates_knowledge_and_ends(self, MockUpdater):
        """Test Librarian calls updater and returns END command"""
        # Given
        state: AgentState = {
            "messages": [],
            "intent_path": "INTENT.md",
            "changed_files": ["src/main.py"],
            "plan_path": "PLAN.md"
        }

        mock_tool_instance = MockUpdater.return_value
        mock_tool_instance.invoke.return_value = {"status": "success"}

        # When
        cmd = librarian_node(state)

        # Then
        # Check tool invocation
        mock_tool_instance.invoke.assert_called_once()
        call_args = mock_tool_instance.invoke.call_args[0][0]
        self.assertIn("verification_result", call_args)
        self.assertEqual(call_args["verification_result"]["intent"], "INTENT.md")
        self.assertEqual(call_args["verification_result"]["changed_files"], ["src/main.py"])

        # Check return command
        self.assertIsInstance(cmd, Command)
        self.assertEqual(cmd.goto, END)
        self.assertIn("Knowledge updated", cmd.update["messages"][0].content)

if __name__ == "__main__":
    unittest.main()
