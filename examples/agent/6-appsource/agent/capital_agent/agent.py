from google.adk.agents import LlmAgent

# Define a tool function
def get_capital_city(country: str) -> str:
  """Retrieves the capital city for a given country."""
  # Replace with actual logic (e.g., API call, database lookup)
  capitals = {"france": "Paris", "japan": "Tokyo", "canada": "Ottawa"}
  return capitals.get(country.lower(), f"Sorry, I don't know the capital of {country}.")


capital_agent = LlmAgent(
    model="gemini-2.0-flash",
    name="capital_agent",
    description="Answers user questions about the capital city of a given country.",
    instruction="""You are an agent that provides the capital city of a country.
             When a user asks for the capital of a country:
             1. Identify the country name from the user's query.
             2. Use the `get_capital_city` tool to find the capital.
             3. Respond clearly to the user, stating the capital city.
             Example Query: "What's the capital of France?"
             Example Response: "The capital of France is Paris."
        """,
    tools=[get_capital_city] # Provide the function directly
)

root_agent = capital_agent
